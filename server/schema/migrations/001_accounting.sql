-- Accounting tables for Ultra Enterprise (non-destructive).
-- Run: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/schema/migrations/001_accounting.sql
-- Optional separate accounts DB: run the same file against ACCOUNTS_DATABASE_URL when split.

BEGIN;

-- ---------------------------------------------------------------------------
-- Core ledgers & journal
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ledgers (
  id              BIGSERIAL PRIMARY KEY,
  name            TEXT NOT NULL,
  group_type      TEXT NOT NULL CHECK (group_type IN ('asset', 'liability', 'income', 'expense')),
  party_kind      TEXT CHECK (party_kind IN ('CUSTOMER', 'SUPPLIER')),
  party_id        BIGINT,
  system_key      TEXT,
  opening_balance NUMERIC(18, 2) NOT NULL DEFAULT 0,
  opening_type    TEXT NOT NULL DEFAULT 'dr' CHECK (opening_type IN ('dr', 'cr')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT ledgers_party_unique UNIQUE (party_kind, party_id),
  CONSTRAINT ledgers_system_key_unique UNIQUE (system_key)
);

CREATE TABLE IF NOT EXISTS journal_entries (
  id                 BIGSERIAL PRIMARY KEY,
  date               DATE NOT NULL,
  voucher_type       TEXT NOT NULL,
  voucher_no         INTEGER NOT NULL,
  voucher_no_display TEXT,
  ledger_id          BIGINT NOT NULL REFERENCES ledgers (id),
  debit              NUMERIC(18, 2) NOT NULL DEFAULT 0,
  credit             NUMERIC(18, 2) NOT NULL DEFAULT 0,
  narration          TEXT,
  source_id          BIGINT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT journal_entries_amount_check CHECK (
    (debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0)
  )
);

CREATE INDEX IF NOT EXISTS journal_entries_voucher_idx
  ON journal_entries (voucher_type, voucher_no);

CREATE INDEX IF NOT EXISTS journal_entries_ledger_date_idx
  ON journal_entries (ledger_id, date);

CREATE INDEX IF NOT EXISTS journal_entries_date_idx
  ON journal_entries (date);

CREATE TABLE IF NOT EXISTS voucher_counters (
  voucher_type TEXT NOT NULL,
  fy           TEXT NOT NULL,
  last_no      INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (voucher_type, fy)
);

-- Cross-database safety: voucher saved on primary DB, posting retried if accounts DB fails.
CREATE TABLE IF NOT EXISTS accounting_posting_outbox (
  id           BIGSERIAL PRIMARY KEY,
  voucher_type TEXT NOT NULL,
  source_id    BIGINT NOT NULL,
  payload      JSONB NOT NULL,
  status       TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'DONE', 'FAILED')),
  last_error   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS accounting_posting_outbox_status_idx
  ON accounting_posting_outbox (status, created_at);

-- ---------------------------------------------------------------------------
-- Voucher display numbers (existing transaction tables unchanged in shape)
-- ---------------------------------------------------------------------------

ALTER TABLE sales_invoices
  ADD COLUMN IF NOT EXISTS voucher_no_display TEXT;

ALTER TABLE sales_invoices
  ADD COLUMN IF NOT EXISTS fwd_charge NUMERIC(18, 2) NOT NULL DEFAULT 0;

-- ---------------------------------------------------------------------------
-- Global internal numbers (never reset per FY); display uses voucher_counters.
-- ---------------------------------------------------------------------------

CREATE SEQUENCE IF NOT EXISTS sales_invoice_number_seq;
CREATE SEQUENCE IF NOT EXISTS purchase_voucher_number_seq;
CREATE SEQUENCE IF NOT EXISTS receipt_voucher_number_seq;
CREATE SEQUENCE IF NOT EXISTS payment_voucher_number_seq;
CREATE SEQUENCE IF NOT EXISTS expense_voucher_number_seq;
CREATE SEQUENCE IF NOT EXISTS salary_voucher_number_seq;

CREATE OR REPLACE FUNCTION sync_global_voucher_sequences() RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  m bigint;
BEGIN
  SELECT COALESCE(MAX(invoice_no), 0) INTO m FROM sales_invoices;
  PERFORM setval('sales_invoice_number_seq', GREATEST(m, 1), m > 0);

  IF to_regclass('public.purchase_vouchers') IS NOT NULL THEN
    SELECT COALESCE(MAX(voucher_no), 0) INTO m FROM purchase_vouchers;
    PERFORM setval('purchase_voucher_number_seq', GREATEST(m, 1), m > 0);
  END IF;

  IF to_regclass('public.receipts') IS NOT NULL THEN
    SELECT COALESCE(MAX(voucher_no), 0) INTO m FROM receipts;
    PERFORM setval('receipt_voucher_number_seq', GREATEST(m, 1), m > 0);
  END IF;

  IF to_regclass('public.payments') IS NOT NULL THEN
    SELECT COALESCE(MAX(voucher_no), 0) INTO m FROM payments;
    PERFORM setval('payment_voucher_number_seq', GREATEST(m, 1), m > 0);
  END IF;

  IF to_regclass('public.expense_vouchers') IS NOT NULL THEN
    SELECT COALESCE(MAX(voucher_no), 0) INTO m FROM expense_vouchers;
    PERFORM setval('expense_voucher_number_seq', GREATEST(m, 1), m > 0);
  END IF;

  IF to_regclass('public.salary_vouchers') IS NOT NULL THEN
    SELECT COALESCE(MAX(voucher_no), 0) INTO m FROM salary_vouchers;
    PERFORM setval('salary_voucher_number_seq', GREATEST(m, 1), m > 0);
  END IF;
END;
$$;

SELECT sync_global_voucher_sequences();

-- Align with VPS: invoice_no is globally unique when present.
CREATE UNIQUE INDEX IF NOT EXISTS sales_invoices_invoice_no_key
  ON sales_invoices (invoice_no)
  WHERE invoice_no IS NOT NULL;

ALTER TABLE purchase_vouchers
  ADD COLUMN IF NOT EXISTS voucher_no_display TEXT;

ALTER TABLE receipts
  ADD COLUMN IF NOT EXISTS voucher_no INTEGER;

ALTER TABLE receipts
  ADD COLUMN IF NOT EXISTS voucher_no_display TEXT;

ALTER TABLE receipts
  ADD COLUMN IF NOT EXISTS cash_bank TEXT NOT NULL DEFAULT 'CASH'
    CHECK (cash_bank IN ('CASH', 'BANK'));

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS voucher_no INTEGER;

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS voucher_no_display TEXT;

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS cash_bank TEXT NOT NULL DEFAULT 'CASH'
    CHECK (cash_bank IN ('CASH', 'BANK'));

CREATE TABLE IF NOT EXISTS expense_vouchers (
  id                 BIGSERIAL PRIMARY KEY,
  uuid               UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  voucher_no         INTEGER NOT NULL,
  voucher_no_display TEXT NOT NULL,
  voucher_date       DATE NOT NULL,
  expense_ledger_id  BIGINT NOT NULL REFERENCES ledgers (id),
  amount             NUMERIC(18, 2) NOT NULL,
  cash_bank          TEXT NOT NULL DEFAULT 'CASH' CHECK (cash_bank IN ('CASH', 'BANK')),
  narration          TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS salary_vouchers (
  id                 BIGSERIAL PRIMARY KEY,
  uuid               UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  voucher_no         INTEGER NOT NULL,
  voucher_no_display TEXT NOT NULL,
  voucher_date       DATE NOT NULL,
  amount             NUMERIC(18, 2) NOT NULL,
  cash_bank          TEXT NOT NULL DEFAULT 'CASH' CHECK (cash_bank IN ('CASH', 'BANK')),
  narration          TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS expense_vouchers_fy_no_idx
  ON expense_vouchers (voucher_no_display);

CREATE UNIQUE INDEX IF NOT EXISTS salary_vouchers_fy_no_idx
  ON salary_vouchers (voucher_no_display);

-- ---------------------------------------------------------------------------
-- Seed system ledgers (idempotent)
-- ---------------------------------------------------------------------------

INSERT INTO ledgers (name, group_type, system_key)
VALUES
  ('Cash', 'asset', 'CASH'),
  ('Bank', 'asset', 'BANK'),
  ('Sales', 'income', 'SALES'),
  ('Purchase', 'expense', 'PURCHASE'),
  ('Output CGST', 'liability', 'OUTPUT_CGST'),
  ('Output SGST', 'liability', 'OUTPUT_SGST'),
  ('Output IGST', 'liability', 'OUTPUT_IGST'),
  ('Input CGST', 'asset', 'INPUT_CGST'),
  ('Input SGST', 'asset', 'INPUT_SGST'),
  ('Input IGST', 'asset', 'INPUT_IGST'),
  ('Freight & Charges', 'income', 'FREIGHT'),
  ('Salary', 'expense', 'SALARY'),
  ('Expenses', 'expense', 'EXPENSES')
ON CONFLICT (system_key) DO NOTHING;

-- One-time copy from legacy ledger_accounts (backup table left untouched).
INSERT INTO ledgers (name, group_type, opening_balance, opening_type)
SELECT
  la.name,
  CASE
    WHEN la.head ILIKE '%income%' OR la.group_name ILIKE '%income%' THEN 'income'
    WHEN la.head ILIKE '%liab%' OR la.group_name ILIKE '%liab%' THEN 'liability'
    WHEN la.head ILIKE '%asset%' OR la.group_name ILIKE '%asset%' THEN 'asset'
    ELSE 'expense'
  END,
  GREATEST(COALESCE(la.dr_amount, 0), COALESCE(la.cr_amount, 0)),
  CASE
    WHEN COALESCE(la.dr_amount, 0) >= COALESCE(la.cr_amount, 0) THEN 'dr'
    ELSE 'cr'
  END
FROM ledger_accounts la
WHERE NOT EXISTS (
  SELECT 1 FROM ledgers l WHERE lower(l.name) = lower(la.name)
);

-- Party ledgers from existing masters (opening from party master).
INSERT INTO ledgers (name, group_type, party_kind, party_id, opening_balance, opening_type)
SELECT
  c.customer_name,
  'asset',
  'CUSTOMER',
  c.id,
  CASE
    WHEN COALESCE(c.opening_balance_dr, 0) >= COALESCE(c.opening_balance_cr, 0)
      THEN COALESCE(c.opening_balance_dr, 0) - COALESCE(c.opening_balance_cr, 0)
    ELSE COALESCE(c.opening_balance_cr, 0) - COALESCE(c.opening_balance_dr, 0)
  END,
  CASE
    WHEN COALESCE(c.opening_balance_dr, 0) >= COALESCE(c.opening_balance_cr, 0) THEN 'dr'
    ELSE 'cr'
  END
FROM customers c
WHERE NOT EXISTS (
  SELECT 1 FROM ledgers l WHERE l.party_kind = 'CUSTOMER' AND l.party_id = c.id
);

INSERT INTO ledgers (name, group_type, party_kind, party_id, opening_balance, opening_type)
SELECT
  COALESCE(s.data::jsonb->>'supplier_name', 'Supplier ' || s.id::text),
  'liability',
  'SUPPLIER',
  s.id,
  CASE
    WHEN COALESCE((s.data::jsonb->>'opening_balance_dr')::numeric, 0)
         >= COALESCE((s.data::jsonb->>'opening_balance_cr')::numeric, 0)
      THEN COALESCE((s.data::jsonb->>'opening_balance_dr')::numeric, 0)
           - COALESCE((s.data::jsonb->>'opening_balance_cr')::numeric, 0)
    ELSE COALESCE((s.data::jsonb->>'opening_balance_cr')::numeric, 0)
         - COALESCE((s.data::jsonb->>'opening_balance_dr')::numeric, 0)
  END,
  CASE
    WHEN COALESCE((s.data::jsonb->>'opening_balance_dr')::numeric, 0)
         >= COALESCE((s.data::jsonb->>'opening_balance_cr')::numeric, 0) THEN 'dr'
    ELSE 'cr'
  END
FROM suppliers s
WHERE NOT EXISTS (
  SELECT 1 FROM ledgers l WHERE l.party_kind = 'SUPPLIER' AND l.party_id = s.id
);

COMMIT;
