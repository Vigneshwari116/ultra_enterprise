#!/usr/bin/env python3
"""
One-time deterministic historical seed for Ultra Enterprise (PostgreSQL).

Parses purchase_data.pdf, sales_data.pdf, and materials.pdf, then inserts:
  state_zones, units, products, customers, suppliers,
  purchase vouchers (+ stock + stock_movements), sales invoices.

SAFE BY DEFAULT: runs in dry-run mode unless --execute is passed.
Does not modify the database without --execute.

Usage:
  export DATABASE_URL='postgresql://...'
  python3 scripts/seed_historical_data.py --pdf-dir /path/to/pdfs
  python3 scripts/seed_historical_data.py --pdf-dir /path/to/pdfs --execute

Requires: pdfplumber, psycopg[binary]
  pip install -r scripts/requirements-historical-seed.txt
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import uuid
from collections import Counter
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR / "historical_seed"))

from pdf_parser import (  # noqa: E402
    customer_dedupe_key,
    infer_state_zone_id,
    load_all_pdfs,
    normalize_hsn,
    normalize_name,
    parse_pdf_date,
    product_key,
    supplier_dedupe_key,
)

EXPECTED = {
    "state_zones": 2,
    "units": 9,
    "products": 982,
    "customers": 16,
    "suppliers": 87,
    "purchase_vouchers": 261,
    "purchase_voucher_items": 874,
    "sales_invoices": 208,
    "sales_invoice_items": 371,
}

UNIT_SEED = [
    ("PCS", "Pieces"),
    ("KG", "Kilogram"),
    ("LTR", "Litre"),
    ("BOX", "Box"),
    ("NOS", "Numbers"),
    ("MTR", "Metre"),
    ("SQM", "Square Metre"),
    ("COIL", "Coil"),
    ("SET", "Set"),
]

STATE_ZONE_SEED = [
    (1, "INTRA", "Intra State"),
    (2, "INTER", "Inter State"),
]

# DNS namespace — fixed seed for reproducible uuid5 values across runs.
NAMESPACE = uuid.UUID("6ba7b810-9dad-11d1-80b4-00c04fd430c8")


def deterministic_uuid(key: str) -> str:
    """Return a stable RFC-4122 UUID string for the given logical key."""
    return str(uuid.uuid5(NAMESPACE, key))


def sha_hex(value: str, length: int = 32) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:length].upper()


def product_key_string(name: str, hsn: str) -> str:
    norm_name, norm_hsn = product_key(name, hsn)
    return f"{norm_name}|{norm_hsn}"


def product_uuid(name: str, hsn: str) -> str:
    return deterministic_uuid(f"PRODUCT:{product_key_string(name, hsn)}")


def product_code(name: str, hsn: str) -> str:
    return f"P{sha_hex(product_key_string(name, hsn), 12)}"


def purchase_uuid(voucher_no: int) -> str:
    """purchase_vouchers.uuid is TEXT — keep human-readable deterministic id."""
    return f"PURCHASE:{voucher_no}"


def sales_uuid(invoice_no: int) -> str:
    return deterministic_uuid(f"SALES:{invoice_no}")


def sales_item_uuid(invoice_no: int, line_no: int) -> str:
    return deterministic_uuid(f"SALES-ITEM:{invoice_no}:{line_no}")


def customer_uuid(dedupe_key: str) -> str:
    return deterministic_uuid(f"CUSTOMER:{dedupe_key}")


def supplier_uuid(dedupe_key: str) -> str:
    return deterministic_uuid(f"SUPPLIER:{dedupe_key}")


def customer_code(dedupe_key: str) -> str:
    return f"C{sha_hex(dedupe_key, 10)}"


def supplier_code(dedupe_key: str) -> str:
    return f"S{sha_hex(dedupe_key, 10)}"


def validate_source_counts(data: dict[str, Any]) -> None:
    checks = {
        "purchase_headers": (len(data["purchase_headers"]), 261),
        "purchase_lines": (len(data["purchase_lines"]), 874),
        "sales_headers": (len(data["sales_headers"]), 208),
        "sales_lines": (len(data["sales_lines"]), 371),
        "materials_rows": (len(data["materials"]), 982),
        "catalog_products": (len(data["catalog"]), 982),
        "suppliers": (len(data["suppliers"]), 87),
        "customers": (len(data["customers"]), 16),
    }
    errors = [f"{name}: got {got}, expected {expected}" for name, (got, expected) in checks.items() if got != expected]
    if errors:
        raise RuntimeError("PDF source count validation failed:\n  " + "\n  ".join(errors))

    materials_unique = len({product_key(m["item_name"], m["hsn"]) for m in data["materials"]})
    if materials_unique != 981:
        raise RuntimeError(f"materials unique keys: got {materials_unique}, expected 981")

    zone_counts = Counter(infer_state_zone_id(h) for h in data["sales_headers"])
    if zone_counts.get(1) != 186 or zone_counts.get(2) != 22:
        raise RuntimeError(
            f"state_zone distribution: got intra={zone_counts.get(1)}, inter={zone_counts.get(2)}; expected 186/22"
        )


def assert_valid_rfc4122_uuid(value: str, label: str) -> None:
    try:
        parsed = uuid.UUID(value)
    except ValueError as exc:
        raise RuntimeError(f"{label}: not a valid RFC-4122 UUID: {value!r}") from exc
    if str(parsed) != value:
        raise RuntimeError(f"{label}: UUID canonical form mismatch: {value!r} != {parsed}")


def validate_generated_uuids(data: dict[str, Any]) -> None:
    """Verify every product/sales UUID is valid RFC-4122 before any DB access."""
    product_uuids: set[str] = set()
    for entry in data["catalog"].values():
        uid = product_uuid(entry["item_name"], entry["hsn"])
        assert_valid_rfc4122_uuid(uid, "product")
        if uid in product_uuids:
            raise RuntimeError(f"duplicate product UUID for key: {product_key_string(entry['item_name'], entry['hsn'])}")
        product_uuids.add(uid)

    sales_uuids: set[str] = set()
    for header in data["sales_headers"]:
        invoice_no = int(header["invoice_no"])
        uid = sales_uuid(invoice_no)
        assert_valid_rfc4122_uuid(uid, "sales_invoice")
        if uid in sales_uuids:
            raise RuntimeError(f"duplicate sales invoice UUID for invoice_no={invoice_no}")
        sales_uuids.add(uid)

    item_uuids: set[str] = set()
    for line in data["sales_lines"]:
        invoice_no = int(line["invoice_no"])
        line_no = int(line["line_no"])
        uid = sales_item_uuid(invoice_no, line_no)
        assert_valid_rfc4122_uuid(uid, "sales_invoice_item")
        if uid in item_uuids:
            raise RuntimeError(
                f"duplicate sales item UUID for invoice_no={invoice_no} line_no={line_no}"
            )
        item_uuids.add(uid)

    for voucher_no in {int(h["bill_no"]) for h in data["purchase_headers"]}:
        pv_uuid = purchase_uuid(voucher_no)
        if not pv_uuid.startswith("PURCHASE:"):
            raise RuntimeError(f"purchase voucher uuid must remain TEXT form: {pv_uuid!r}")


def connect(database_url: str):
    import psycopg

    return psycopg.connect(database_url)


def fetch_one(cur, sql: str, params: tuple[Any, ...] = ()) -> Any:
    cur.execute(sql, params)
    row = cur.fetchone()
    return row[0] if row else None


def seed_state_zones(cur) -> None:
    for zone_id, code, name in STATE_ZONE_SEED:
        cur.execute(
            """
            INSERT INTO state_zones (id, code, name, is_active, created_at)
            VALUES (%s, %s, %s, true, NOW())
            ON CONFLICT (id) DO NOTHING
            """,
            (zone_id, code, name),
        )


def seed_units(cur) -> dict[str, int]:
    unit_ids: dict[str, int] = {}
    for code, name in UNIT_SEED:
        existing = fetch_one(cur, "SELECT id FROM units WHERE UPPER(code) = UPPER(%s)", (code,))
        if existing:
            unit_ids[code] = int(existing)
            continue
        cur.execute(
            """
            INSERT INTO units (code, name, description, is_active, created_at)
            VALUES (%s, %s, %s, true, NOW())
            RETURNING id
            """,
            (code, name, name),
        )
        unit_ids[code] = int(cur.fetchone()[0])
    return unit_ids


def seed_products(cur, catalog: dict[tuple[str, str], dict[str, Any]], unit_ids: dict[str, int]) -> dict[tuple[str, str], int]:
    product_ids: dict[tuple[str, str], int] = {}
    for key, entry in sorted(catalog.items(), key=lambda item: item[0]):
        uuid = product_uuid(entry["item_name"], entry["hsn"])
        code = product_code(entry["item_name"], entry["hsn"])
        unit_code = entry.get("uom") or "PCS"
        unit_id = unit_ids.get(unit_code) or unit_ids["PCS"]

        existing = fetch_one(
            cur,
            "SELECT id FROM products WHERE uuid = %s::uuid OR product_code = %s",
            (uuid, code),
        )
        if existing:
            product_ids[key] = int(existing)
            continue

        cur.execute(
            """
            INSERT INTO products (
              uuid, product_code, product_name, unit_id, hsn_code,
              sales_rate, purchase_rate, gst_rate, reorder_level, is_active, created_at
            ) VALUES (
              %s, %s, %s, %s, %s,
              %s, %s, %s, 0, true, NOW()
            )
            RETURNING id
            """,
            (
                uuid,
                code,
                entry["item_name"],
                unit_id,
                entry["hsn"] or None,
                entry["sales_rate"],
                entry["purchase_rate"],
                entry["gst_rate"],
            ),
        )
        product_ids[key] = int(cur.fetchone()[0])
    return product_ids


def seed_customers(cur, customers: dict[str, dict[str, Any]]) -> dict[str, int]:
    customer_ids: dict[str, int] = {}
    for dedupe_key, header in sorted(customers.items()):
        uuid = customer_uuid(dedupe_key)
        code = customer_code(dedupe_key)
        existing = fetch_one(
            cur,
            "SELECT id FROM customers WHERE uuid = %s::uuid OR customer_code = %s",
            (uuid, code),
        )
        if existing:
            customer_ids[dedupe_key] = int(existing)
            continue

        cur.execute(
            """
            INSERT INTO customers (
              uuid, customer_code, customer_name, address, city, postal_pincode, gstin,
              opening_balance_cr, opening_balance_dr, is_active, created_at
            ) VALUES (
              %s, %s, %s, %s, %s, %s, %s,
              0, 0, true, NOW()
            )
            RETURNING id
            """,
            (
                uuid,
                code,
                header["customer_name"],
                header.get("address") or "",
                header.get("city") or "",
                header.get("pincode") or "",
                header.get("gstin") or "",
            ),
        )
        customer_ids[dedupe_key] = int(cur.fetchone()[0])
    return customer_ids


def seed_suppliers(cur, suppliers: dict[str, dict[str, Any]]) -> dict[str, int]:
    supplier_ids: dict[str, int] = {}
    for dedupe_key, header in sorted(suppliers.items()):
        uuid = supplier_uuid(dedupe_key)
        existing = fetch_one(cur, "SELECT id FROM suppliers WHERE uuid = %s::uuid", (uuid,))
        if existing:
            supplier_ids[dedupe_key] = int(existing)
            continue

        payload = {
            "supplier_code": supplier_code(dedupe_key),
            "supplier_name": header["supplier_name"],
            "address": header.get("address") or "",
            "city": header.get("city") or "",
            "postal_pincode": header.get("pincode") or "",
            "gstin": header.get("gstin") or "",
            "primary_mobile": "",
            "bank_name": "",
            "bank_account_no": "",
            "ifsc_code": "",
            "branch_address": "",
        }
        cur.execute(
            """
            INSERT INTO suppliers (uuid, status, data, created_at)
            VALUES (%s, 'ACTIVE', %s::jsonb, NOW())
            RETURNING id
            """,
            (uuid, json.dumps(payload)),
        )
        supplier_ids[dedupe_key] = int(cur.fetchone()[0])
    return supplier_ids


def purchase_voucher_exists(cur, voucher_no: int, uuid: str) -> bool:
    existing = fetch_one(
        cur,
        """
        SELECT id FROM purchase_vouchers
        WHERE uuid = %s
           OR (data->>'voucher_no')::int = %s
        LIMIT 1
        """,
        (uuid, voucher_no),
    )
    return existing is not None


def sales_invoice_exists(cur, invoice_no: int) -> bool:
    invoice_uuid = sales_uuid(invoice_no)
    existing = fetch_one(
        cur,
        """
        SELECT id FROM sales_invoices
        WHERE uuid = %s::uuid OR invoice_no = %s
        LIMIT 1
        """,
        (invoice_uuid, invoice_no),
    )
    return existing is not None


def apply_stock_increase(cur, product_id: int, qty: float, created_at: str) -> float:
    cur.execute(
        """
        INSERT INTO stock (product_id, quantity, updated_at)
        VALUES (%s, %s, %s::timestamptz)
        ON CONFLICT (product_id) DO UPDATE
        SET quantity = stock.quantity + EXCLUDED.quantity,
            updated_at = EXCLUDED.updated_at
        RETURNING quantity
        """,
        (product_id, qty, created_at),
    )
    return float(cur.fetchone()[0])


def insert_stock_movement(
    cur,
    product_id: int,
    qty: float,
    balance_after: float,
    created_at: str,
) -> None:
    cur.execute(
        """
        INSERT INTO stock_movements (
          product_id, movement_type, reference_type, reference_id,
          quantity, balance_after, created_at
        ) VALUES (%s, 'PURCHASE_VOUCHER', NULL, NULL, %s, %s, %s::timestamptz)
        """,
        (product_id, qty, balance_after, created_at),
    )


def seed_purchase_vouchers(
    cur,
    data: dict[str, Any],
    supplier_ids: dict[str, int],
    product_ids: dict[tuple[str, str], int],
) -> dict[str, int]:
    stats = Counter()
    headers = sorted(
        data["purchase_headers"],
        key=lambda row: (parse_pdf_date(row["bill_date"]), row["bill_no"]),
    )

    for header in headers:
        voucher_no = int(header["bill_no"])
        uuid = purchase_uuid(voucher_no)
        if purchase_voucher_exists(cur, voucher_no, uuid):
            stats["skipped_vouchers"] += 1
            continue

        supplier_id = supplier_ids[supplier_dedupe_key(header)]
        voucher_date = parse_pdf_date(header["bill_date"])
        created_at = f"{voucher_date}T12:00:00+00:00"

        voucher_data = {
            "uuid": uuid,
            "voucher_no": voucher_no,
            "voucher_date": voucher_date,
            "supplier_invoice_no": header.get("supplier_inv_no") or "",
            "supplier_invoice_date": voucher_date,
            "purchase_order_id": None,
            "supplier_id": supplier_id,
            "taxable_total": header["taxable_total"],
            "cgst_total": header["cgst_total"],
            "sgst_total": header["sgst_total"],
            "igst_total": header["igst_total"],
            "grand_total": header["grand_total"],
            "status": "POSTED",
        }

        cur.execute(
            """
            INSERT INTO purchase_vouchers (uuid, status, data, created_at)
            VALUES (%s, 'POSTED', %s::jsonb, %s::timestamptz)
            RETURNING id
            """,
            (uuid, json.dumps(voucher_data), created_at),
        )
        parent_id = int(cur.fetchone()[0])
        stats["inserted_vouchers"] += 1

        for line in data["lines_by_voucher"].get(voucher_no, []):
            key = product_key(line["item_name"], line["hsn"])
            product_id = product_ids[key]
            item_data = {
                "product_id": product_id,
                "description": line["item_name"],
                "uom": line.get("uom") or "PCS",
                "hsn": line.get("hsn") or "",
                "quantity": line["qty"],
                "rate": line["rate"],
                "cgst_percent": line["cgst_percent"],
                "sgst_percent": line["sgst_percent"],
                "igst_percent": line["igst_percent"],
                "taxable": line["taxable"],
                "cgst": line["cgst"],
                "sgst": line["sgst"],
                "igst": line["igst"],
                "total": line["total"],
            }
            cur.execute(
                """
                INSERT INTO purchase_voucher_items (parent_id, data, created_at)
                VALUES (%s, %s::jsonb, %s::timestamptz)
                """,
                (parent_id, json.dumps(item_data), created_at),
            )
            stats["inserted_items"] += 1

            qty = float(line["qty"])
            if qty > 0:
                balance_after = apply_stock_increase(cur, product_id, qty, created_at)
                insert_stock_movement(cur, product_id, qty, balance_after, created_at)
                stats["stock_movements"] += 1

    return dict(stats)


def seed_sales_invoices(
    cur,
    data: dict[str, Any],
    customer_ids: dict[str, int],
    product_ids: dict[tuple[str, str], int],
    unit_ids: dict[str, int],
) -> dict[str, int]:
    stats = Counter()
    headers = sorted(
        data["sales_headers"],
        key=lambda row: (parse_pdf_date(row["transaction_date"]), row["invoice_no"]),
    )

    for header in headers:
        invoice_no = int(header["invoice_no"])
        invoice_uuid = sales_uuid(invoice_no)
        if sales_invoice_exists(cur, invoice_no):
            stats["skipped_invoices"] += 1
            continue

        customer_id = customer_ids[customer_dedupe_key(header)]
        transaction_date = parse_pdf_date(header["transaction_date"])
        compound_gst_total = round(
            float(header["cgst_total"]) + float(header["sgst_total"]) + float(header["igst_total"]),
            2,
        )

        cur.execute(
            """
            INSERT INTO sales_invoices (
              uuid, invoice_no, transaction_date, customer_id, state_zone_id,
              po_no, po_date, challan_dc_no, challan_dc_date,
              total_packages, vehicle_dispatch_mode, due_days, eway_bill_no,
              taxable_total, cgst_total, sgst_total, igst_total,
              compound_gst_total, grand_total, status
            ) VALUES (
              %s, %s, %s::date, %s, %s,
              %s, NULL, '', NULL,
              0, '', 0, '',
              %s, %s, %s, %s,
              %s, %s, 'POSTED'
            )
            RETURNING id
            """,
            (
                invoice_uuid,
                invoice_no,
                transaction_date,
                customer_id,
                infer_state_zone_id(header),
                header.get("po_no") or "",
                header["taxable_total"],
                header["cgst_total"],
                header["sgst_total"],
                header["igst_total"],
                compound_gst_total,
                header["grand_total"],
            ),
        )
        invoice_id = int(cur.fetchone()[0])
        stats["inserted_invoices"] += 1

        for line in data["lines_by_invoice"].get(invoice_no, []):
            key = product_key(line["item_name"], line["hsn"])
            product_id = product_ids[key]
            catalog_entry = data["catalog"][key]
            unit_code = catalog_entry.get("uom") or "PCS"
            unit_id = unit_ids.get(unit_code) or unit_ids["PCS"]

            cur.execute(
                """
                INSERT INTO sales_invoice_items (
                  uuid, invoice_id, product_id, description, unit_id, hsn_code,
                  quantity, rate, cgst_percent, sgst_percent, igst_percent,
                  taxable_amount, cgst_amount, sgst_amount, igst_amount, compound_total
                ) VALUES (
                  %s, %s, %s, %s, %s, %s,
                  %s, %s, %s, %s, %s,
                  %s, %s, %s, %s, %s
                )
                """,
                (
                    sales_item_uuid(invoice_no, line["line_no"]),
                    invoice_id,
                    product_id,
                    line["item_name"],
                    unit_id,
                    line.get("hsn") or "",
                    line["qty"],
                    line["rate"],
                    line["cgst_percent"],
                    line["sgst_percent"],
                    line["igst_percent"],
                    line["taxable"],
                    line["cgst"],
                    line["sgst"],
                    line["igst"],
                    line["compound_total"],
                ),
            )
            stats["inserted_items"] += 1

    return dict(stats)


def dry_run_report(data: dict[str, Any]) -> None:
    print("=== Ultra Enterprise historical seed (DRY RUN) ===")
    print(f"Purchase vouchers: {len(data['purchase_headers'])} headers, {len(data['purchase_lines'])} lines")
    print(f"Sales invoices:    {len(data['sales_headers'])} headers, {len(data['sales_lines'])} lines")
    print(f"Materials rows:    {len(data['materials'])} ({len({product_key(m['item_name'], m['hsn']) for m in data['materials']})} unique)")
    print(f"Products:          {len(data['catalog'])}")
    print(f"Suppliers:         {len(data['suppliers'])}")
    print(f"Customers:         {len(data['customers'])}")
    zone_counts = Counter(infer_state_zone_id(h) for h in data["sales_headers"])
    print(f"State zones:       intra={zone_counts.get(1)}, inter={zone_counts.get(2)}")
    uoms = Counter(entry.get("uom") or "PCS" for entry in data["catalog"].values())
    print(f"Product UOMs:      {dict(sorted(uoms.items()))}")
    positive_lines = sum(1 for line in data["purchase_lines"] if float(line["qty"]) > 0)
    print(f"Positive purchase lines (stock movements): {positive_lines}")
    print(f"Product UUIDs (uuid5):     {len(data['catalog'])} validated")
    print(f"Sales invoice UUIDs:       {len(data['sales_headers'])} validated")
    print(f"Sales item UUIDs:          {len(data['sales_lines'])} validated")
    print(f"Purchase voucher UUIDs:    TEXT form PURCHASE:{{n}} ({len(data['purchase_headers'])})")
    print("No database changes were made.")


def run_seed(database_url: str, data: dict[str, Any]) -> None:
    import psycopg

    with psycopg.connect(database_url) as conn:
        with conn.transaction():
            with conn.cursor() as cur:
                seed_state_zones(cur)
                unit_ids = seed_units(cur)
                product_ids = seed_products(cur, data["catalog"], unit_ids)
                customer_ids = seed_customers(cur, data["customers"])
                supplier_ids = seed_suppliers(cur, data["suppliers"])
                purchase_stats = seed_purchase_vouchers(cur, data, supplier_ids, product_ids)
                sales_stats = seed_sales_invoices(cur, data, customer_ids, product_ids, unit_ids)

    print("=== Seed complete ===")
    print(json.dumps({"purchase": purchase_stats, "sales": sales_stats}, indent=2))


def resolve_pdf_dir(path: Path) -> Path:
    if not path.exists():
        raise FileNotFoundError(f"PDF directory not found: {path}")
    required = ["purchase_data.pdf", "sales_data.pdf", "materials.pdf"]
    missing = [name for name in required if not (path / name).exists()]
    if missing:
        raise FileNotFoundError(f"Missing PDFs in {path}: {', '.join(missing)}")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description="Ultra Enterprise one-time historical seed")
    parser.add_argument(
        "--pdf-dir",
        type=Path,
        default=Path(os.environ.get("ULTRA_SEED_PDF_DIR", ".")),
        help="Directory containing purchase_data.pdf, sales_data.pdf, materials.pdf",
    )
    parser.add_argument(
        "--database-url",
        default=os.environ.get("DATABASE_URL", ""),
        help="PostgreSQL connection string (required with --execute)",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Apply seed to the database (default is dry-run only)",
    )
    args = parser.parse_args()

    pdf_dir = resolve_pdf_dir(args.pdf_dir)
    data = load_all_pdfs(pdf_dir)
    validate_source_counts(data)
    validate_generated_uuids(data)

    if not args.execute:
        dry_run_report(data)
        print("\nRe-run with --execute to apply. Validation SQL: scripts/validate_historical_seed.sql")
        return 0

    if not args.database_url:
        print("ERROR: DATABASE_URL or --database-url is required with --execute", file=sys.stderr)
        return 1

    run_seed(args.database_url, data)
    print("Run scripts/validate_historical_seed.sql to verify counts.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
