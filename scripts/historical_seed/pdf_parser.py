"""PDF table extraction for Ultra Enterprise historical seed (pdfplumber)."""
from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path
from typing import Any

import pdfplumber

HEADER_PURCHASE_COLS = {
    "bill no",
    "bill date",
    "supplier name",
    "address",
    "city",
    "pincode",
    "gstin",
}
HEADER_SALES_COLS = {"bill no", "bill date", "customer name", "address", "city", "pincode", "gstin"}
LINE_PURCHASE_COLS = {"bill no", "line #", "item name", "hsn", "qty", "uom", "rate", "amount"}
LINE_SALES_COLS = {"bill no", "line #", "item name", "hsn", "qty", "rate", "amount"}


def parse_money(value: str | None) -> float:
    if value is None:
        return 0.0
    text = str(value).strip().replace("\n", " ")
    if not text:
        return 0.0
    text = text.replace(",", "")
    match = re.search(r"-?\d+(?:\.\d+)?", text)
    if not match:
        raise ValueError(f"no numeric value in: {value!r}")
    return float(match.group(0))


def normalize_uom(code: str | None) -> str:
    if not code:
        return ""
    cleaned = str(code).strip()
    if not cleaned:
        return ""
    if cleaned.lower() == "nos":
        return "NOS"
    return cleaned.upper()


def normalize_hsn(hsn: str | None) -> str:
    if hsn is None:
        return ""
    text = str(hsn).strip()
    if text in ("0", "0.0", ""):
        return ""
    return text


def normalize_name(name: str) -> str:
    return re.sub(r"\s+", " ", name.strip()).upper()


def product_key(name: str, hsn: str) -> tuple[str, str]:
    return normalize_name(name), normalize_hsn(hsn)


def clean_cell(value: Any) -> str:
    if value is None:
        return ""
    return str(value).replace("\n", " ").strip()


def table_kind(header_row: list[Any]) -> str | None:
    cols = {clean_cell(c).lower() for c in header_row if c}
    if LINE_PURCHASE_COLS.issubset(cols):
        return "purchase_lines"
    if LINE_SALES_COLS.issubset(cols):
        return "sales_lines"
    if HEADER_PURCHASE_COLS.issubset(cols):
        return "purchase_headers"
    if HEADER_SALES_COLS.issubset(cols):
        return "sales_headers"
    return None


def col_index(header_row: list[Any], name: str) -> int:
    target = name.lower()
    for index, cell in enumerate(header_row):
        if clean_cell(cell).lower() == target:
            return index
    raise KeyError(name)


def parse_purchase_headers(rows: list[list[Any]], header: list[Any]) -> list[dict[str, Any]]:
    idx = {
        name: col_index(header, name)
        for name in [
            "Bill No",
            "Bill Date",
            "Supplier Name",
            "Address",
            "City",
            "Pincode",
            "GSTIN",
            "Supplier Inv No",
            "Payment Terms",
            "Taxable Amt",
            "CGST",
            "SGST",
            "IGST",
            "Grand Total",
        ]
    }
    out: list[dict[str, Any]] = []
    for row in rows:
        if not row or not row[idx["Bill No"]]:
            continue
        out.append(
            {
                "bill_no": int(clean_cell(row[idx["Bill No"]])),
                "bill_date": clean_cell(row[idx["Bill Date"]]),
                "supplier_name": clean_cell(row[idx["Supplier Name"]]).replace("\n", " "),
                "address": clean_cell(row[idx["Address"]]),
                "city": clean_cell(row[idx["City"]]),
                "pincode": clean_cell(row[idx["Pincode"]]),
                "gstin": clean_cell(row[idx["GSTIN"]]),
                "supplier_inv_no": clean_cell(row[idx["Supplier Inv No"]]),
                "payment_terms": clean_cell(row[idx["Payment Terms"]]),
                "taxable_total": parse_money(row[idx["Taxable Amt"]]),
                "cgst_total": parse_money(row[idx["CGST"]]),
                "sgst_total": parse_money(row[idx["SGST"]]),
                "igst_total": parse_money(row[idx["IGST"]]),
                "grand_total": parse_money(row[idx["Grand Total"]]),
            }
        )
    return out


def parse_purchase_lines(rows: list[list[Any]], header: list[Any]) -> list[dict[str, Any]]:
    idx = {
        name: col_index(header, name)
        for name in [
            "Bill No",
            "Line #",
            "Item Name",
            "HSN",
            "Qty",
            "UOM",
            "Rate",
            "Amount",
            "CGST%",
            "CGST Amt",
            "SGST%",
            "SGST Amt",
            "IGST%",
            "IGST Amt",
            "Line Total",
        ]
    }
    out: list[dict[str, Any]] = []
    for row in rows:
        if not row or not row[idx["Bill No"]]:
            continue
        out.append(
            {
                "bill_no": int(clean_cell(row[idx["Bill No"]])),
                "line_no": int(clean_cell(row[idx["Line #"]])),
                "item_name": clean_cell(row[idx["Item Name"]]).replace("\n", " "),
                "hsn": normalize_hsn(row[idx["HSN"]]),
                "qty": parse_money(row[idx["Qty"]]),
                "uom": normalize_uom(row[idx["UOM"]]),
                "rate": parse_money(row[idx["Rate"]]),
                "taxable": parse_money(row[idx["Amount"]]),
                "cgst_percent": parse_money(row[idx["CGST%"]]),
                "cgst": parse_money(row[idx["CGST Amt"]]),
                "sgst_percent": parse_money(row[idx["SGST%"]]),
                "sgst": parse_money(row[idx["SGST Amt"]]),
                "igst_percent": parse_money(row[idx["IGST%"]]),
                "igst": parse_money(row[idx["IGST Amt"]]),
                "total": parse_money(row[idx["Line Total"]]),
            }
        )
    return out


def parse_sales_headers(rows: list[list[Any]], header: list[Any]) -> list[dict[str, Any]]:
    idx = {
        name: col_index(header, name)
        for name in [
            "Bill No",
            "Bill Date",
            "Customer Name",
            "Address",
            "City",
            "Pincode",
            "GSTIN",
            "PO No",
            "Payment Terms",
            "Taxable Amt",
            "CGST",
            "SGST",
            "IGST",
            "Grand Total",
        ]
    }
    out: list[dict[str, Any]] = []
    for row in rows:
        if not row or not row[idx["Bill No"]]:
            continue
        out.append(
            {
                "invoice_no": int(clean_cell(row[idx["Bill No"]])),
                "transaction_date": clean_cell(row[idx["Bill Date"]]),
                "customer_name": clean_cell(row[idx["Customer Name"]]).replace("\n", " "),
                "address": clean_cell(row[idx["Address"]]),
                "city": clean_cell(row[idx["City"]]),
                "pincode": clean_cell(row[idx["Pincode"]]),
                "gstin": clean_cell(row[idx["GSTIN"]]),
                "po_no": clean_cell(row[idx["PO No"]]),
                "payment_terms": clean_cell(row[idx["Payment Terms"]]),
                "taxable_total": parse_money(row[idx["Taxable Amt"]]),
                "cgst_total": parse_money(row[idx["CGST"]]),
                "sgst_total": parse_money(row[idx["SGST"]]),
                "igst_total": parse_money(row[idx["IGST"]]),
                "grand_total": parse_money(row[idx["Grand Total"]]),
            }
        )
    return out


def parse_sales_lines(rows: list[list[Any]], header: list[Any]) -> list[dict[str, Any]]:
    idx = {
        name: col_index(header, name)
        for name in [
            "Bill No",
            "Line #",
            "Item Name",
            "HSN",
            "Qty",
            "Rate",
            "Amount",
            "CGST%",
            "CGST Amt",
            "SGST%",
            "SGST Amt",
            "IGST%",
            "IGST Amt",
            "Line Total",
        ]
    }
    out: list[dict[str, Any]] = []
    for row in rows:
        if not row or not row[idx["Bill No"]]:
            continue
        taxable = parse_money(row[idx["Amount"]])
        cgst = parse_money(row[idx["CGST Amt"]])
        sgst = parse_money(row[idx["SGST Amt"]])
        igst = parse_money(row[idx["IGST Amt"]])
        out.append(
            {
                "invoice_no": int(clean_cell(row[idx["Bill No"]])),
                "line_no": int(clean_cell(row[idx["Line #"]])),
                "item_name": clean_cell(row[idx["Item Name"]]).replace("\n", " "),
                "hsn": normalize_hsn(row[idx["HSN"]]),
                "qty": parse_money(row[idx["Qty"]]),
                "rate": parse_money(row[idx["Rate"]]),
                "taxable": taxable,
                "cgst_percent": parse_money(row[idx["CGST%"]]),
                "cgst": cgst,
                "sgst_percent": parse_money(row[idx["SGST%"]]),
                "sgst": sgst,
                "igst_percent": parse_money(row[idx["IGST%"]]),
                "igst": igst,
                "compound_total": round(taxable + cgst + sgst + igst, 2),
            }
        )
    return out


def parse_materials_pdf(path: Path) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            for table in page.extract_tables() or []:
                if not table or len(table) < 2:
                    continue
                header = [clean_cell(c).lower() for c in table[0]]
                if "item name" not in header or "hsn" not in header:
                    continue
                name_i = header.index("item name")
                hsn_i = header.index("hsn")
                uom_i = header.index("uom") if "uom" in header else None
                rate_i = next((i for i, c in enumerate(header) if "rate" in c), None)
                used_i = next((i for i, c in enumerate(header) if "used" in c), None)
                for row in table[1:]:
                    if not row or not row[name_i]:
                        continue
                    items.append(
                        {
                            "item_name": clean_cell(row[name_i]),
                            "hsn": normalize_hsn(row[hsn_i]),
                            "uom": normalize_uom(row[uom_i]) if uom_i is not None else "",
                            "latest_rate": parse_money(row[rate_i]) if rate_i is not None else 0.0,
                            "used_in": clean_cell(row[used_i]) if used_i is not None else "",
                        }
                    )
    return items


def load_pdf_data(path: Path, doc: str) -> dict[str, list[dict[str, Any]]]:
    purchase_headers: list[dict[str, Any]] = []
    purchase_lines: list[dict[str, Any]] = []
    sales_headers: list[dict[str, Any]] = []
    sales_lines: list[dict[str, Any]] = []

    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            for table in page.extract_tables() or []:
                if not table or not table[0]:
                    continue
                kind = table_kind(table[0])
                if kind == "purchase_headers":
                    purchase_headers.extend(parse_purchase_headers(table[1:], table[0]))
                elif kind in ("purchase_lines", "sales_lines"):
                    if doc == "purchase":
                        purchase_lines.extend(parse_purchase_lines(table[1:], table[0]))
                    else:
                        sales_lines.extend(parse_sales_lines(table[1:], table[0]))
                elif kind == "sales_headers":
                    sales_headers.extend(parse_sales_headers(table[1:], table[0]))

    return {
        "purchase_headers": purchase_headers,
        "purchase_lines": purchase_lines,
        "sales_headers": sales_headers,
        "sales_lines": sales_lines,
    }


def dedupe_headers_by_key(
    headers: list[dict[str, Any]], key_name: str
) -> list[dict[str, Any]]:
    deduped: dict[int, dict[str, Any]] = {}
    for row in headers:
        deduped[int(row[key_name])] = row
    return [deduped[k] for k in sorted(deduped)]


def supplier_dedupe_key(row: dict[str, Any]) -> str:
    gstin = (row.get("gstin") or "").strip().upper()
    if gstin:
        return f"gstin:{gstin}"
    name = normalize_name(row.get("supplier_name") or "")
    city = normalize_name(row.get("city") or "")
    return f"name:{name}|city:{city}"


def customer_dedupe_key(row: dict[str, Any]) -> str:
    gstin = (row.get("gstin") or "").strip().upper()
    if gstin:
        return f"gstin:{gstin}"
    name = normalize_name(row.get("customer_name") or "")
    city = normalize_name(row.get("city") or "")
    return f"name:{name}|city:{city}"


def parse_pdf_date(value: str) -> str:
    """Convert PDF date like 01-Apr-2026 to ISO yyyy-mm-dd."""
    from datetime import datetime

    return datetime.strptime(value.strip(), "%d-%b-%Y").strftime("%Y-%m-%d")


def infer_state_zone_id(header: dict[str, Any]) -> int:
    cgst = float(header.get("cgst_total") or 0)
    sgst = float(header.get("sgst_total") or 0)
    igst = float(header.get("igst_total") or 0)
    if igst > 0 and cgst == 0 and sgst == 0:
        return 2
    return 1


def build_product_catalog(
    purchase_lines: list[dict[str, Any]],
    sales_lines: list[dict[str, Any]],
    materials: list[dict[str, Any]],
) -> dict[tuple[str, str], dict[str, Any]]:
    materials_by_key: dict[tuple[str, str], dict[str, Any]] = {}
    for row in materials:
        key = product_key(row["item_name"], row["hsn"])
        existing = materials_by_key.get(key)
        if existing is None or row.get("latest_rate", 0) >= existing.get("latest_rate", 0):
            materials_by_key[key] = row

    catalog: dict[tuple[str, str], dict[str, Any]] = {}

    def touch(line: dict[str, Any], source: str) -> None:
        key = product_key(line["item_name"], line["hsn"])
        entry = catalog.setdefault(
            key,
            {
                "item_name": line["item_name"].strip(),
                "hsn": normalize_hsn(line["hsn"]),
                "uoms": defaultdict(int),
                "purchase_rate": 0.0,
                "sales_rate": 0.0,
                "gst_rate": 0.0,
                "sources": set(),
            },
        )
        if line.get("uom"):
            entry["uoms"][line["uom"]] += 1
        rate = float(line.get("rate") or 0)
        if source == "purchase":
            entry["purchase_rate"] = rate
        else:
            entry["sales_rate"] = rate
        gst = float(line.get("cgst_percent") or 0) + float(line.get("sgst_percent") or 0)
        if gst <= 0:
            gst = float(line.get("igst_percent") or 0)
        if gst > entry["gst_rate"]:
            entry["gst_rate"] = gst
        entry["sources"].add(source)

    for line in purchase_lines:
        touch(line, "purchase")
    for line in sales_lines:
        touch(line, "sales")

    for key, entry in catalog.items():
        material = materials_by_key.get(key)
        if material:
            if not entry["uoms"] and material.get("uom"):
                entry["uoms"][material["uom"]] = 1
            if entry["purchase_rate"] <= 0 and material.get("latest_rate"):
                entry["purchase_rate"] = float(material["latest_rate"])
            if entry["sales_rate"] <= 0 and material.get("latest_rate"):
                entry["sales_rate"] = float(material["latest_rate"])

        if entry["uoms"]:
            entry["uom"] = max(entry["uoms"].items(), key=lambda item: item[1])[0]
        elif material and material.get("uom"):
            entry["uom"] = material["uom"]
        else:
            entry["uom"] = "PCS"

        if entry["sales_rate"] <= 0:
            entry["sales_rate"] = entry["purchase_rate"]
        if entry["purchase_rate"] <= 0:
            entry["purchase_rate"] = entry["sales_rate"]
        if entry["gst_rate"] <= 0:
            entry["gst_rate"] = 18.0

    return catalog


def load_all_pdfs(pdf_dir: Path) -> dict[str, Any]:
    purchase = load_pdf_data(pdf_dir / "purchase_data.pdf", "purchase")
    sales = load_pdf_data(pdf_dir / "sales_data.pdf", "sales")
    materials = parse_materials_pdf(pdf_dir / "materials.pdf")

    purchase_headers = dedupe_headers_by_key(purchase["purchase_headers"], "bill_no")
    sales_headers = dedupe_headers_by_key(sales["sales_headers"], "invoice_no")

    purchase_lines = sorted(
        purchase["purchase_lines"],
        key=lambda row: (row["bill_no"], row["line_no"]),
    )
    sales_lines = sorted(
        sales["sales_lines"],
        key=lambda row: (row["invoice_no"], row["line_no"]),
    )

    catalog = build_product_catalog(purchase_lines, sales_lines, materials)

    suppliers: dict[str, dict[str, Any]] = {}
    for header in purchase_headers:
        suppliers[supplier_dedupe_key(header)] = header

    customers: dict[str, dict[str, Any]] = {}
    for header in sales_headers:
        customers[customer_dedupe_key(header)] = header

    lines_by_voucher: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for line in purchase_lines:
        lines_by_voucher[line["bill_no"]].append(line)

    lines_by_invoice: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for line in sales_lines:
        lines_by_invoice[line["invoice_no"]].append(line)

    return {
        "purchase_headers": purchase_headers,
        "purchase_lines": purchase_lines,
        "sales_headers": sales_headers,
        "sales_lines": sales_lines,
        "materials": materials,
        "catalog": catalog,
        "suppliers": suppliers,
        "customers": customers,
        "lines_by_voucher": lines_by_voucher,
        "lines_by_invoice": lines_by_invoice,
    }
