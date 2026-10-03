#!/usr/bin/env bash
set -euo pipefail
BASE="${ULTRA_API_URL:-https://api.ultra.winagrum.tech}"

pass() { echo "PASS $*"; }
fail() { echo "FAIL $*"; }
skip() { echo "NEEDS MANUAL TEST $*"; }

echo "=== Live API smoke tests against $BASE ==="

code=$(curl -sS -o /tmp/health.json -w "%{http_code}" "$BASE/health")
if [[ "$code" == "200" ]] && grep -q ultra_enterprise /tmp/health.json; then
  pass GET /health
else
  fail GET /health "http=$code"
fi

code=$(curl -sS -o /tmp/pv.json -w "%{http_code}" "$BASE/api/purchase-vouchers")
if [[ "$code" == "200" ]]; then
  pass GET /api/purchase-vouchers
  if python3 -c "import json; d=json.load(open('/tmp/pv.json')); assert isinstance(d,list) and d and 'data' in d[0]" 2>/dev/null; then
    pass "purchase-vouchers envelope shape"
  else
    fail "purchase-vouchers envelope shape"
  fi
else
  fail GET /api/purchase-vouchers
fi

latest_id=$(python3 -c "import json; d=json.load(open('/tmp/pv.json')); print(d[0]['id'] if d else '')" 2>/dev/null || true)
if [[ -n "$latest_id" ]]; then
  code=$(curl -sS -o /tmp/pv_one.json -w "%{http_code}" "$BASE/api/purchase-vouchers/$latest_id")
  if [[ "$code" == "200" ]] && grep -q '"voucher"' /tmp/pv_one.json && grep -q '"items"' /tmp/pv_one.json; then
    pass "GET /api/purchase-vouchers/$latest_id"
  else
    fail "GET /api/purchase-vouchers/$latest_id" "http=$code body=$(head -c 120 /tmp/pv_one.json)"
  fi
fi

for path in /api/purchase-orders /api/quotations /api/receipts /api/payments; do
  code=$(curl -sS -o /dev/null -w "%{http_code}" "$BASE$path")
  if [[ "$code" == "200" ]]; then pass "GET $path"; else fail "GET $path" "http=$code"; fi
done

code=$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$BASE/api/customers" -H 'Content-Type: application/json' -d '{"customer_name":"QA-LIVE"}')
if [[ "$code" == "200" || "$code" == "201" ]]; then pass POST /api/customers; else fail POST /api/customers "http=$code"; fi
