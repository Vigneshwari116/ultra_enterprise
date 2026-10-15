-- Minimal Ultra schema slice for accounting phase-1 integration tests.
DROP TABLE IF EXISTS journal_entries CASCADE;
DROP TABLE IF EXISTS ledgers CASCADE;
DROP TABLE IF EXISTS voucher_counters CASCADE;
DROP TABLE IF EXISTS accounting_posting_outbox CASCADE;
DROP TABLE IF EXISTS sales_invoice_items CASCADE;
DROP TABLE IF EXISTS sales_invoices CASCADE;
DROP TABLE IF EXISTS expense_vouchers CASCADE;
DROP TABLE IF EXISTS salary_vouchers CASCADE;
DROP TABLE IF EXISTS receipts CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS purchase_vouchers CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS units CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS ledger_accounts CASCADE;
DROP TABLE IF EXISTS state_zones CASCADE;

CREATE TABLE state_zones (
  id   SERIAL PRIMARY KEY,
  name TEXT NOT NULL
);

INSERT INTO state_zones (id, name) VALUES (1, 'Intra State'), (2, 'Inter State');

CREATE TABLE units (
  id   SERIAL PRIMARY KEY,
  code TEXT NOT NULL,
  name TEXT NOT NULL
);

INSERT INTO units (id, code, name) VALUES (1, 'PCS', 'Pieces');

CREATE TABLE customers (
  id                  SERIAL PRIMARY KEY,
  uuid                UUID NOT NULL DEFAULT gen_random_uuid(),
  customer_code       TEXT,
  customer_name       TEXT NOT NULL,
  opening_balance_cr  NUMERIC(18, 2) DEFAULT 0,
  opening_balance_dr  NUMERIC(18, 2) DEFAULT 0,
  is_active           BOOLEAN DEFAULT TRUE
);

INSERT INTO customers (id, customer_name) VALUES (1, 'Phase1 Test Customer');

CREATE TABLE suppliers (
  id         SERIAL PRIMARY KEY,
  uuid       UUID NOT NULL DEFAULT gen_random_uuid(),
  status     TEXT DEFAULT 'ACTIVE',
  data       JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE ledger_accounts (
  id          SERIAL PRIMARY KEY,
  name        TEXT NOT NULL,
  group_name  TEXT,
  head        TEXT,
  cr_amount   NUMERIC(18, 2) DEFAULT 0,
  dr_amount   NUMERIC(18, 2) DEFAULT 0
);

CREATE TABLE products (
  id        SERIAL PRIMARY KEY,
  uuid      UUID NOT NULL DEFAULT gen_random_uuid(),
  product_name TEXT NOT NULL,
  unit_id   INT REFERENCES units (id),
  is_active BOOLEAN DEFAULT TRUE
);

INSERT INTO products (id, product_name, unit_id) VALUES (1, 'Test Widget', 1);

CREATE TABLE sales_invoices (
  id                  SERIAL PRIMARY KEY,
  uuid                UUID NOT NULL UNIQUE,
  invoice_no          INTEGER,
  voucher_no_display  TEXT,
  customer_id         INT REFERENCES customers (id),
  transaction_date    TIMESTAMPTZ,
  po_no               TEXT,
  po_date             TIMESTAMPTZ,
  state_zone_id       INT REFERENCES state_zones (id),
  challan_dc_no       TEXT,
  challan_dc_date     TIMESTAMPTZ,
  total_packages      INT DEFAULT 0,
  vehicle_dispatch_mode TEXT,
  due_days            INT DEFAULT 0,
  eway_bill_no        TEXT,
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
  id SERIAL PRIMARY KEY,
  uuid UUID NOT NULL DEFAULT gen_random_uuid(),
  voucher_no INTEGER,
  status TEXT DEFAULT 'POSTED'
);

CREATE TABLE receipts (
  id SERIAL PRIMARY KEY,
  customer_id INT,
  receipt_date DATE,
  amount NUMERIC(18, 2) DEFAULT 0,
  narration TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE payments (
  id SERIAL PRIMARY KEY,
  supplier_id INT,
  payment_date DATE,
  amount NUMERIC(18, 2) DEFAULT 0,
  narration TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
