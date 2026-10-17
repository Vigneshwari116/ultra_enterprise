# Phase 1 manual verify (`ultra_copy` + API test container)

Project on VPS: `/root/ultra_api_test` (mounted as `/app` in Dart test container).  
API smoke container: `http://127.0.0.1:3004` (adjust if different).

Host has no `psql` / `jq` / `git` — use `docker exec` into Postgres and curl only.

## Dart tests (test DB only)

```bash
export TEST_DATABASE_URL='postgresql://USER:PASS@127.0.0.1:55432/ultra_copy_test?sslmode=disable'

docker run --rm --network host \
  -v /root/ultra_api_test:/app \
  -w /app/server \
  -e TEST_DATABASE_URL \
  dart:3.5.4 bash -lc '
    apt-get update -qq && apt-get install -y -qq postgresql-client >/dev/null
    dart pub get
    dart analyze
    dart test test/test_fixture_paths_test.dart test/vps_integration_test.dart --reporter expanded
  '
```

## Smoke data on `ultra_copy` (after your POST smoke)

| Display | Internal `voucher_no` / `invoice_no` | Notes |
|---------|--------------------------------------|--------|
| SAL-26-27-1 | `invoice_no` **209** | grand **6100** |
| PUR-26-27-1 | **263** | grand **1298** |
| PUR-26-27-2 | **264** | grand **1298** |
| PUR-26-27-3 | **265** | grand **1298** (good candidate to **delete**) |
| REC-26-27-1 | **1** | amount **1000**, cash |
| PAY-26-27-1 | **1** | amount **500**, bank |

Customer for receipts: **`customer_id` 17** (not 1).

Resolve envelope **row `id`** for PUT/DELETE (internal numbers stay as above):

```bash
docker exec pg-inspect-testing psql -U ultra_app -d ultra_copy -c \
"SELECT id, voucher_no_display, data::jsonb->>'voucher_no' AS voucher_no
 FROM purchase_vouchers
 WHERE voucher_no_display IN ('PUR-26-27-1','PUR-26-27-2','PUR-26-27-3')
 ORDER BY (data::jsonb->>'voucher_no')::int;"

docker exec pg-inspect-testing psql -U ultra_app -d ultra_copy -c \
"SELECT id, voucher_no_display, data::jsonb->>'amount' AS amount
 FROM receipts WHERE voucher_no_display = 'REC-26-27-1';"

docker exec pg-inspect-testing psql -U ultra_app -d ultra_copy -c \
"SELECT id, invoice_no, voucher_no_display FROM sales_invoices WHERE invoice_no = 209;"
```

Set shell variables from the `id` column (examples — replace with your query output):

```bash
API=http://127.0.0.1:3004
REC_ID=...        # receipts.id for REC-26-27-1
PUR3_ID=...       # purchase_vouchers.id for PUR-26-27-3 (voucher_no 265)
```

### Journals before edit/delete

```bash
docker exec pg-inspect-testing psql -U ultra_app -d ultra_copy -c \
"SELECT j.voucher_type, j.voucher_no, j.voucher_no_display, l.name, j.debit, j.credit
 FROM journal_entries j
 JOIN ledgers l ON l.id = j.ledger_id
 WHERE (j.voucher_type, j.voucher_no) IN (
   ('SAL',209),('PUR',263),('PUR',264),('PUR',265),('REC',1),('PAY',1)
 )
 ORDER BY j.voucher_type, j.voucher_no, j.id;"
```

### Edit — receipt **1000 → 1100** (keeps `REC-26-27-1`, `voucher_no` 1)

```bash
curl -sS -X PUT "$API/api/receipts/$REC_ID" \
  -H 'Content-Type: application/json' \
  -d '{"customer_id":17,"receipt_date":"2026-10-21","amount":1100,"narration":"updated amount","cash_bank":"CASH"}'
```

Expected HTTP **200** body shape:

```json
{"id":<REC_ID>,"receipt":{"id":<REC_ID>,"voucher_no":1,"voucher_no_display":"REC-26-27-1"}}
```

Expected journals for `voucher_type='REC' AND voucher_no=1`: **Dr Cash 1100**, **Cr customer ledger 1100**.

```bash
docker exec pg-inspect-testing psql -U ultra_app -d ultra_copy -c \
"SELECT l.name, j.debit, j.credit FROM journal_entries j
 JOIN ledgers l ON l.id = j.ledger_id
 WHERE j.voucher_type = 'REC' AND j.voucher_no = 1 ORDER BY j.id;"
```

### Delete — **PUR-26-27-3** (`voucher_no` **265**, number not reused)

```bash
curl -sS -X DELETE "$API/api/purchase-vouchers/$PUR3_ID"
```

Expected: `{"id":<PUR3_ID>,"deleted":true}`

After delete:

```bash
docker exec pg-inspect-testing psql -U ultra_app -d ultra_copy -c \
"SELECT COUNT(*) AS pv_rows FROM purchase_vouchers WHERE id = $PUR3_ID;"

docker exec pg-inspect-testing psql -U ultra_app -d ultra_copy -c \
"SELECT COUNT(*) AS je_rows FROM journal_entries WHERE voucher_type = 'PUR' AND voucher_no = 265;"
```

Both counts should be **0**. PUR **263** / **264** unchanged.
