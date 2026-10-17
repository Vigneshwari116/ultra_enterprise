# `001_accounting.sql` idempotency

The **ledger_accounts copy block is removed** from this migration (VPS `ledger_accounts` is envelope-only).

Verify on a throwaway DB with the real schema fixture:

```bash
export TEST_DATABASE_URL='postgresql://USER:PASS@127.0.0.1:55432/ultra_copy_test?sslmode=disable'
cd server/test/fixtures
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f reset_test_schema.sql
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f vps_ultra_enterprise_schema.sql
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f vps_ultra_enterprise_seed.sql
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f ../../schema/migrations/001_accounting.sql
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f ../../schema/migrations/001_accounting.sql
echo "Second apply should exit 0"
```
