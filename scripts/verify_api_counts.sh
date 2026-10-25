#!/usr/bin/env bash
# Read-only row counts via public Ultra REST API (not a substitute for PostgreSQL verification).
set -euo pipefail
BASE="${ULTRA_API_URL:-https://api.ultra.winagrum.tech}"
python3 <<PY
import json, urllib.request
BASE = "$BASE"
paths = [
    ("customers", "/api/customers"),
    ("suppliers", "/api/suppliers"),
    ("products", "/api/products"),
    ("purchase_orders", "/api/purchase-orders"),
    ("purchase_vouchers", "/api/purchase-vouchers"),
    ("sales_invoices", "/api/sales-invoices"),
    ("units", "/api/units"),
    ("material_types", "/api/material-types"),
]
for label, path in paths:
    try:
        with urllib.request.urlopen(BASE + path) as resp:
            data = json.load(resp)
        n = len(data) if isinstance(data, list) else "?"
    except Exception as e:
        n = f"error ({e})"
    print(f"{label:20} {n}")
PY
