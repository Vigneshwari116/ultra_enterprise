-- Sales invoice bill type (normal tax invoice vs labour bill) and labour SEL DC fields.

ALTER TABLE sales_invoices
  ADD COLUMN IF NOT EXISTS bill_type character varying(10) DEFAULT 'NORMAL';

ALTER TABLE sales_invoices
  ADD COLUMN IF NOT EXISTS sel_dc_no character varying(100);

ALTER TABLE sales_invoices
  ADD COLUMN IF NOT EXISTS sel_dc_date date;

UPDATE sales_invoices SET bill_type = 'NORMAL' WHERE bill_type IS NULL;
