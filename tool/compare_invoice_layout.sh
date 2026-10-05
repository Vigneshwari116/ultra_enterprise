#!/usr/bin/env bash
set -euo pipefail
REF_PDF="${1:-/home/ubuntu/.cursor/projects/workspace/uploads/testinf_print__1__5c6d.pdf}"
APP_PDF="${2:-/tmp/ultra_app_page1.pdf}"
OUT="/opt/cursor/artifacts"
mkdir -p "$OUT"
pdftoppm -r 100 -f 1 -l 1 "$REF_PDF" "$OUT/ref_page1" -png
pdftoppm -r 100 -f 1 -l 1 "$APP_PDF" "$OUT/app_page1" -png
convert "$OUT/ref_page1-1.png" "$OUT/app_page1-1.png" +append "$OUT/invoice_side_by_side.png"
convert "$OUT/ref_page1-1.png" "$OUT/app_page1-1.png" -compose difference -composite "$OUT/invoice_diff.png"
echo "Wrote $OUT/invoice_side_by_side.png and $OUT/invoice_diff.png"
