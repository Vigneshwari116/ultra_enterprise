# Run PR #21 API on VPS against `ultra_copy`

Standalone test container **`ultra_api_test`** on loopback **3004**. Production containers and ports are unchanged.

## Prerequisites on VPS

1. **Database** `ultra_copy` reachable on the host at `127.0.0.1:55432` (or adjust URL).
2. **One-time migration** on `ultra_copy` (idempotent; no `ledger_accounts` copy block — see [MIGRATION_IDEMPOTENCY.md](./MIGRATION_IDEMPOTENCY.md)):

```bash
psql "postgresql://USER:PASS@127.0.0.1:55432/ultra_copy" \
  -v ON_ERROR_STOP=1 \
  -f /path/to/ultra_enterprise/server/schema/migrations/001_accounting.sql
```

3. **Docker network** used by your other apps (example name `shared`):

```bash
docker network ls   # pick the existing shared network name
```

## Deploy test container

```bash
cd /path/to/ultra_enterprise/server
git fetch && git checkout cursor/global-invoice-seq-767e   # or merge PR #21
cp .env.example .env
# edit .env: DATABASE_URL user/password, DOCKER_NETWORK if not "shared"

docker compose up -d --build
docker compose ps
docker compose logs -f ultra_api_test
```

### Equivalent `docker run` (no compose file)

```bash
docker build -t ultra_api_test:local .

docker run -d \
  --name ultra_api_test \
  --restart unless-stopped \
  --network shared \
  --add-host host.docker.internal:host-gateway \
  -p 127.0.0.1:3004:3000 \
  -e PORT=3000 \
  -e DATABASE_URL='postgresql://ultra_app:PASS@host.docker.internal:55432/ultra_copy' \
  ultra_api_test:local
```

## Environment variables

| Variable | Required | Example | Notes |
|----------|----------|---------|--------|
| `DATABASE_URL` | **Yes** | `postgresql://ultra_app:***@host.docker.internal:55432/ultra_copy` | Primary Postgres; all posting uses this DB in PR #21. |
| `PORT` | No | `3000` | Listen port **inside** the container (map with `-p 127.0.0.1:3004:3000`). |
| `ACCOUNTS_DATABASE_URL` | No | — | Reserved for split accounts DB; **not used** by merged routes today. |
| `DOCKER_NETWORK` | Compose only | `shared` | External network name in `docker-compose.yml`. |

No API keys, JWT, or Flutter config are required for these routes.

## Health check

```bash
curl -sS http://127.0.0.1:3004/health | jq .
```

Expected: `{"ok":true,"database":"ultra_enterprise"}` (static label in handler; connection is your `DATABASE_URL` DB).

## Smoke test: sales + purchase

Replace placeholders with **your** `ultra_copy` ids (customer, intra `state_zone_id`, products, supplier).

```bash
export API=http://127.0.0.1:3004
export CUSTOMER_ID=1          # ← your customer id
export STATE_ZONE_ID=1        # ← intra-state zone id in ultra_copy
export PRODUCT_ID_SALES=1     # ← product id for sales line
export SUPPLIER_ID=92         # ← your supplier id (sample VPS had 92)
export PRODUCT_ID_PURCHASE=1124  # ← product id for purchase line
```

### POST sales invoice (intra-state + freight)

```bash
curl -sS -X POST "$API/api/sales-invoices" \
  -H 'Content-Type: application/json' \
  -d "{
    \"customer_id\": $CUSTOMER_ID,
    \"state_zone_id\": $STATE_ZONE_ID,
    \"transaction_date\": \"2026-10-20\",
    \"taxable_total\": 5000,
    \"cgst_total\": 450,
    \"sgst_total\": 450,
    \"igst_total\": 0,
    \"fwd_charge\": 200,
    \"grand_total\": 6100,
    \"items\": [{
      \"product_id\": $PRODUCT_ID_SALES,
      \"description\": \"VPS smoke test line\",
      \"hsn\": \"8471\",
      \"quantity\": 1,
      \"rate\": 5000,
      \"taxable\": 5000,
      \"cgst_percent\": 9,
      \"sgst_percent\": 9,
      \"cgst\": 450,
      \"sgst\": 450,
      \"total\": 5900
    }]
  }" | jq .
```

Note: `201` returns `invoice.invoice_no` (global seq) and `invoice.voucher_no_display` (e.g. `SAL-26-27-n`).

### POST purchase voucher (header totals — VPS shape)

```bash
curl -sS -X POST "$API/api/purchase-vouchers" \
  -H 'Content-Type: application/json' \
  -d "{
    \"uuid\": \"PURCHASE:smoke-test\",
    \"status\": \"POSTED\",
    \"supplier_id\": $SUPPLIER_ID,
    \"voucher_date\": \"2026-08-10\",
    \"taxable_total\": 1100.0,
    \"cgst_total\": 99.0,
    \"sgst_total\": 99.0,
    \"igst_total\": 0.0,
    \"grand_total\": 1298.0,
    \"purchase_order_id\": null,
    \"supplier_invoice_no\": \"SMOKE/001\",
    \"supplier_invoice_date\": \"2026-08-10\",
    \"items\": [{
      \"product_id\": $PRODUCT_ID_PURCHASE,
      \"description\": \"6 DIA QRC RK\",
      \"uom\": \"NOS\",
      \"hsn\": \"7412\",
      \"quantity\": 50.0,
      \"rate\": 25.0,
      \"cgst_percent\": 9.0,
      \"sgst_percent\": 9.0,
      \"igst_percent\": 18.0,
      \"taxable\": 1250.0,
      \"cgst\": 101.25,
      \"sgst\": 101.25,
      \"igst\": 0.0,
      \"total\": 1328.0
    }]
  }" | jq .
```

Item line totals intentionally differ from the header; journals use **header** amounts only.

## SQL verification (`ultra_copy`)

Run on the host (or `psql` with the same URL as `DATABASE_URL`).

### Latest sales + purchase headers (numbers)

```sql
SELECT id, invoice_no, voucher_no_display, grand_total, transaction_date::date
FROM sales_invoices
ORDER BY id DESC
LIMIT 3;

SELECT id,
       data::jsonb->>'voucher_no' AS voucher_no,
       voucher_no_display,
       data::jsonb->>'grand_total' AS grand_total,
       data::jsonb->>'voucher_date' AS voucher_date
FROM purchase_vouchers
ORDER BY id DESC
LIMIT 3;
```

### Journal lines for the vouchers you just created

Use the `invoice_no` / `voucher_no` from the API response (global internal numbers), not `voucher_no_display`.

```sql
-- Sales (voucher_type SAL): replace :sal_no with invoice_no from POST response
SELECT j.voucher_no_display, l.name AS ledger, j.debit, j.credit, j.narration
FROM journal_entries j
JOIN ledgers l ON l.id = j.ledger_id
WHERE j.voucher_type = 'SAL' AND j.voucher_no = :sal_no
ORDER BY j.id;

-- Purchase (voucher_type PUR): replace :pur_no with voucher_no from POST response
SELECT j.voucher_no_display, l.name AS ledger, j.debit, j.credit, j.narration
FROM journal_entries j
JOIN ledgers l ON l.id = j.ledger_id
WHERE j.voucher_type = 'PUR' AND j.voucher_no = :pur_no
ORDER BY j.id;
```

### Balance check (debit = credit) per voucher

```sql
SELECT voucher_type, voucher_no, voucher_no_display,
       SUM(debit) AS total_debit,
       SUM(credit) AS total_credit,
       SUM(debit) - SUM(credit) AS diff
FROM journal_entries
WHERE (voucher_type, voucher_no) IN (
  ('SAL', :sal_no),
  ('PUR', :pur_no)
)
GROUP BY voucher_type, voucher_no, voucher_no_display;
```

`diff` should be **0** for each row.

### All journals still balanced (optional)

```sql
SELECT SUM(debit) AS dr, SUM(credit) AS cr, SUM(debit) - SUM(credit) AS diff
FROM journal_entries;
```

## What the container needs

| Need | In image? |
|------|-----------|
| Dart SDK / AOT runtime | **Yes** (multi-stage `Dockerfile`) |
| PostgreSQL client | **No** (server uses `postgres` package over TCP) |
| Flutter | **No** |
| VPS `ultra_server` binary | **No** — this image runs **`server/bin/server.dart`** merged routes only |

Only **network access** to Postgres (`host.docker.internal:55432`) and an applied **`001_accounting.sql`** on `ultra_copy` are required beyond env vars.

## Stop test container

```bash
docker compose down
# or: docker rm -f ultra_api_test
```

Production services on other ports are unaffected.
