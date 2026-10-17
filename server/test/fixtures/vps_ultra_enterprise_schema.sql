-- Structural subset matching production VPS (envelope tables + sales columns used by merged routes).
-- Full pg_dump -s belongs here on the VPS; this file is the minimal CI/test slice.

DROP TABLE IF EXISTS journal_entries CASCADE;
DROP TABLE IF EXISTS ledgers CASCADE;
DROP TABLE IF EXISTS voucher_counters CASCADE;
DROP TABLE IF EXISTS purchase_voucher_items CASCADE;
DROP TABLE IF EXISTS purchase_vouchers CASCADE;
DROP TABLE IF EXISTS sales_invoice_items CASCADE;
DROP TABLE IF EXISTS sales_invoices CASCADE;
DROP TABLE IF EXISTS receipts CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS ledger_accounts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS units CASCADE;
DROP TABLE IF EXISTS state_zones CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;

DROP SEQUENCE IF EXISTS sales_invoice_number_seq CASCADE;
DROP SEQUENCE IF EXISTS purchase_voucher_number_seq CASCADE;

CREATE TABLE state_zones (
  id   SERIAL PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE units (
  id   SERIAL PRIMARY KEY,
  code TEXT NOT NULL,
  name TEXT NOT NULL
);

CREATE TABLE customers (
  id                  SERIAL PRIMARY KEY,
  uuid                UUID NOT NULL DEFAULT gen_random_uuid(),
  customer_code       TEXT,
  customer_name       TEXT NOT NULL,
  opening_balance_cr  NUMERIC(18, 2) DEFAULT 0,
  opening_balance_dr  NUMERIC(18, 2) DEFAULT 0,
  is_active           BOOLEAN DEFAULT TRUE,
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE suppliers (
  id         SERIAL PRIMARY KEY,
  uuid       TEXT NOT NULL,
  status     TEXT DEFAULT 'ACTIVE',
  data       TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE ledger_accounts (
  id         SERIAL PRIMARY KEY,
  uuid       TEXT NOT NULL,
  status     TEXT DEFAULT 'ACTIVE',
  data       TEXT NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE products (
  id           SERIAL PRIMARY KEY,
  uuid         UUID NOT NULL DEFAULT gen_random_uuid(),
  product_name TEXT NOT NULL,
  unit_id      INT REFERENCES units (id),
  is_active    BOOLEAN DEFAULT TRUE
);

CREATE TABLE sales_invoices (
  id                  SERIAL PRIMARY KEY,
  uuid                UUID NOT NULL UNIQUE,
  invoice_no          BIGINT,
  voucher_no_display  TEXT,
  customer_id         INT REFERENCES customers (id),
  transaction_date    TIMESTAMPTZ,
  state_zone_id       INT REFERENCES state_zones (id),
  taxable_total       NUMERIC(18, 2) DEFAULT 0,
  cgst_total          NUMERIC(18, 2) DEFAULT 0,
  sgst_total          NUMERIC(18, 2) DEFAULT 0,
  igst_total          NUMERIC(18, 2) DEFAULT 0,
  compound_gst_total  NUMERIC(18, 2) DEFAULT 0,
  fwd_charge          NUMERIC(18, 2) DEFAULT 0,
  grand_total         NUMERIC(18, 2) DEFAULT 0,
  status              TEXT DEFAULT 'POSTED',
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE sales_invoice_items (
  id              SERIAL PRIMARY KEY,
  uuid            UUID NOT NULL DEFAULT gen_random_uuid(),
  invoice_id      INT REFERENCES sales_invoices (id) ON DELETE CASCADE,
  product_id      INT REFERENCES products (id),
  unit_id         INT REFERENCES units (id),
  description     TEXT,
  hsn_code        TEXT,
  quantity        NUMERIC(18, 3) DEFAULT 0,
  rate            NUMERIC(18, 2) DEFAULT 0,
  cgst_percent    NUMERIC(8, 2) DEFAULT 0,
  sgst_percent    NUMERIC(8, 2) DEFAULT 0,
  igst_percent    NUMERIC(8, 2) DEFAULT 0,
  taxable_amount  NUMERIC(18, 2) DEFAULT 0,
  cgst_amount     NUMERIC(18, 2) DEFAULT 0,
  sgst_amount     NUMERIC(18, 2) DEFAULT 0,
  igst_amount     NUMERIC(18, 2) DEFAULT 0,
  compound_total  NUMERIC(18, 2) DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE purchase_vouchers (
  id                 SERIAL PRIMARY KEY,
  uuid               TEXT NOT NULL,
  status             TEXT DEFAULT 'LIVE',
  data               TEXT NOT NULL,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  voucher_no_display TEXT
);

CREATE TABLE purchase_voucher_items (
  id        SERIAL PRIMARY KEY,
  parent_id INTEGER NOT NULL REFERENCES purchase_vouchers (id) ON DELETE CASCADE,
  data      TEXT NOT NULL
);

CREATE TABLE receipts (
  id                 SERIAL PRIMARY KEY,
  uuid               TEXT NOT NULL,
  kind               TEXT DEFAULT 'RECEIPT',
  data               TEXT NOT NULL,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  voucher_no_display TEXT
);

CREATE TABLE payments (
  id                 SERIAL PRIMARY KEY,
  uuid               TEXT NOT NULL,
  kind               TEXT DEFAULT 'PAYMENT',
  data               TEXT NOT NULL,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  voucher_no_display TEXT
);

CREATE TABLE purchase_orders (
  id      SERIAL PRIMARY KEY,
  po_no   TEXT,
  po_date DATE
);
