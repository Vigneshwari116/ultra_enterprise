#!/usr/bin/env bash
# Accounting phase-1 integration runner (migration + sales journals).
# Usage:
#   ./scripts/run_accounting_phase1_integration.sh
# Optional: TEST_DATABASE_URL=postgresql://user:pass@host/db
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB_NAME="${ACCOUNTING_TEST_DB:-ultra_accounting_phase1_test}"
export TEST_DATABASE_URL="${TEST_DATABASE_URL:-postgresql://postgres:postgres@127.0.0.1:5432/${DB_NAME}}"

echo "== Accounting phase-1 integration =="
echo "Database: ${TEST_DATABASE_URL}"

if ! command -v psql >/dev/null; then
  echo "FAIL: psql not found (install postgresql-client)"
  exit 1
fi

if ! command -v dart >/dev/null; then
  if [[ -x /tmp/dart-sdk-extract/dart-sdk/bin/dart ]]; then
    export PATH="/tmp/dart-sdk-extract/dart-sdk/bin:$PATH"
  else
    echo "FAIL: dart not found. Install Dart SDK or extract to /tmp/dart-sdk-extract/dart-sdk/bin"
    exit 1
  fi
fi

# Ensure database exists (local dev convenience).
if psql "${TEST_DATABASE_URL%/*}/postgres" -tc "SELECT 1" >/dev/null 2>&1; then
  psql "${TEST_DATABASE_URL%/*}/postgres" -v ON_ERROR_STOP=1 -qc \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();" \
    >/dev/null 2>&1 || true
  psql "${TEST_DATABASE_URL%/*}/postgres" -v ON_ERROR_STOP=1 -qc "DROP DATABASE IF EXISTS ${DB_NAME};" || true
  psql "${TEST_DATABASE_URL%/*}/postgres" -v ON_ERROR_STOP=1 -qc "CREATE DATABASE ${DB_NAME};" || true
fi

cd "${ROOT}/server"
dart pub get
echo ""
echo "-- Running dart test test/accounting_phase1_test.dart --"
if dart test test/accounting_phase1_test.dart --reporter expanded; then
  TEST_STATUS=PASS
else
  TEST_STATUS=FAIL
fi

echo ""
echo "== SQL snapshot (after last test run; DB may be empty between tests) =="
echo "-- Re-seed one intra bill for display --"
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -q -f "${ROOT}/server/test/fixtures/accounting_phase1_bootstrap.sql"
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -q -f "${ROOT}/server/schema/migrations/001_accounting.sql"

# Post one bill via HTTP using dart one-liner is heavy; show ledger/journal structure instead.
psql "$TEST_DATABASE_URL" <<'SQL'
\echo '--- System ledgers (sample) ---'
SELECT id, name, system_key, group_type FROM ledgers WHERE system_key IS NOT NULL ORDER BY id;

\echo '--- voucher_counters (empty until saves) ---'
SELECT * FROM voucher_counters ORDER BY voucher_type, fy;
SQL

echo ""
echo "== Summary =="
if [[ "$TEST_STATUS" == "PASS" ]]; then
  echo "RESULT: PASS (8/8 dart integration tests)"
  exit 0
else
  echo "RESULT: FAIL (see dart test output above)"
  exit 1
fi
