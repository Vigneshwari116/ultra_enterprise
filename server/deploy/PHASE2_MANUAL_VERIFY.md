# Phase 2 manual verify — expense & salary vouchers (`ultra_copy`)

Project: `/root/ultra_api_test` → mount as `/app` in Docker.  
API: `http://127.0.0.1:3004` (adjust if needed).  
SQL via: `docker exec pg-inspect-testing psql -U ultra_app -d ultra_copy -c "..."`

Reference party/product ids on your copy: **customer 17**, **supplier 92**, **product 983** (not required for expense/salary POST bodies).

## Dart tests (`ultra_copy_test` only)

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

Expected: **19** tests (4 helper + 15 integration) after Phase 2.

## Expense ledger dropdown

```bash
API=http://127.0.0.1:3004
curl -sS "$API/api/expense-ledgers"
```

Lists `ledgers` with `group_type = expense` (includes default **Expenses**).

Pick `expense_ledger_id` from the response, or omit it to default to system **Expenses**.

## POST expense (cash) — EXP-26-27-n

```bash
curl -sS -X POST "$API/api/expense-vouchers" \
  -H 'Content-Type: application/json' \
  -d '{"voucher_date":"2026-10-28","amount":500,"narration":"petty cash","cash_bank":"CASH"}'
```

Expected **201**:

```json
{"id":<id>,"voucher":{"id":<id>,"voucher_no":<n>,"voucher_no_display":"EXP-26-27-<fy_seq>"}}
```

Journals (`voucher_type='EXP'`, `voucher_no=<n>`): **Dr Expenses 500**, **Cr Cash 500**.

```bash
docker exec pg-inspect-testing psql -U ultra_app -d ultra_copy -c \
"SELECT l.name, j.debit, j.credit FROM journal_entries j
 JOIN ledgers l ON l.id = j.ledger_id
 WHERE j.voucher_type = 'EXP' AND j.voucher_no = <n> ORDER BY j.id;"
```

## POST salary (bank) — SLR-26-27-n

```bash
curl -sS -X POST "$API/api/salary-vouchers" \
  -H 'Content-Type: application/json' \
  -d '{"voucher_date":"2026-10-29","amount":12000,"narration":"salary payout","cash_bank":"BANK"}'
```

Expected **201** with `voucher_no_display` like `SLR-26-27-1`.

Journals: **Dr Salary 12000**, **Cr Bank 12000**.

## PUT expense (same numbers, new amount)

Use row `id` from POST response as `EXP_ID`:

```bash
curl -sS -X PUT "$API/api/expense-vouchers/$EXP_ID" \
  -H 'Content-Type: application/json' \
  -d '{"voucher_date":"2026-10-28","amount":600,"narration":"revised","cash_bank":"CASH"}'
```

Expected **200**; `voucher_no` and `voucher_no_display` unchanged; journals show **600** on expense and cash lines.

## DELETE salary

```bash
curl -sS -X DELETE "$API/api/salary-vouchers/$SLR_ID"
```

Expected: `{"id":<SLR_ID>,"deleted":true}` — no `salary_vouchers` row and no `journal_entries` for that `voucher_type='SLR'` + `voucher_no`.
