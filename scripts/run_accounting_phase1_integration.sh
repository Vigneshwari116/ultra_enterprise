#!/usr/bin/env bash
# VPS-shaped accounting integration tests (real schema fixture + 001_accounting.sql).
# Usage:
#   export TEST_DATABASE_URL='postgresql://USER:PASS@127.0.0.1:55432/ultra_copy_test?sslmode=disable'
#   ./scripts/run_accounting_phase1_integration.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -z "${TEST_DATABASE_URL:-}" ]]; then
  echo "FAIL: set TEST_DATABASE_URL to a database whose name ends in _test (e.g. ultra_copy_test)."
  exit 1
fi

DB_NAME="${TEST_DATABASE_URL##*/}"
DB_NAME="${DB_NAME%%\?*}"
if [[ "$DB_NAME" != *_test ]]; then
  echo "FAIL: TEST_DATABASE_URL database must end with _test (got: $DB_NAME)"
  exit 1
fi

echo "== VPS accounting integration =="
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

cd "${ROOT}/server"
dart pub get
echo ""
echo "-- Running dart test test/test_fixture_paths_test.dart test/vps_integration_test.dart --"
dart test test/test_fixture_paths_test.dart test/vps_integration_test.dart --reporter expanded
