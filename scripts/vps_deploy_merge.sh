#!/usr/bin/env bash
# Merge missing Ultra API routes into existing VPS /root/ultra_server (non-destructive).
set -euo pipefail

VPS_HOST="${VPS_HOST:-187.127.180.135}"
ULTRA_SERVER_DIR="${ULTRA_SERVER_DIR:-/root/ultra_server}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY_FILE="${TMPDIR:-/tmp}/vps_deploy_key_$$"

if [[ -z "${VPS_SSH_PRIVATE_KEY:-}" ]]; then
  echo "ERROR: VPS_SSH_PRIVATE_KEY is not set." >&2
  exit 1
fi

umask 077
printf '%s\n' "$VPS_SSH_PRIVATE_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"
SSH=(ssh -i "$KEY_FILE" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "root@${VPS_HOST}")
SCP=(scp -i "$KEY_FILE" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

BACKUP_NAME="ultra_server_backup_$(date -u +%Y%m%d_%H%M%S)"
echo "=== Backup ${ULTRA_SERVER_DIR} -> /root/${BACKUP_NAME} ==="
"${SSH[@]}" "cp -a '${ULTRA_SERVER_DIR}' '/root/${BACKUP_NAME}'"

echo "=== Upload merged route package ==="
"${SSH[@]}" "mkdir -p '${ULTRA_SERVER_DIR}/lib/routes' '${ULTRA_SERVER_DIR}/lib'"
for f in \
  json_util.dart http.dart sql_supplier.dart register_merged_routes.dart; do
  "${SCP[@]}" "${REPO_ROOT}/server/lib/${f}" "root@${VPS_HOST}:${ULTRA_SERVER_DIR}/lib/${f}"
done
for f in \
  purchase_vouchers.dart masters.dart purchase_orders.dart quotations.dart \
  delivery_challans.dart cash_transactions.dart journal.dart ledger.dart \
  adjustment_notes.dart material_types.dart; do
  "${SCP[@]}" "${REPO_ROOT}/server/lib/routes/${f}" "root@${VPS_HOST}:${ULTRA_SERVER_DIR}/lib/routes/${f}"
done

echo "=== Wire registerMergedRoutes into existing entry (manual step if marker missing) ==="
"${SSH[@]}" bash -s <<REMOTE
set -euo pipefail
cd '${ULTRA_SERVER_DIR}'
MAIN=""
for c in bin/server.dart lib/main.dart lib/api.dart; do
  [[ -f "\$c" ]] && MAIN="\$c" && break
done
[[ -n "\$MAIN" ]] || { echo "No main dart file found"; exit 1; }
if ! grep -q registerMergedRoutes "\$MAIN"; then
  echo "Add to \$MAIN after Router/Connection setup:"
  echo "  import 'register_merged_routes.dart';"
  echo "  registerMergedRoutes(router, conn);"
fi
REMOTE

echo "=== dart pub get && analyze ==="
"${SSH[@]}" "cd '${ULTRA_SERVER_DIR}' && dart pub get && dart analyze 2>&1 | tail -30"

echo "=== Restart service ==="
"${SSH[@]}" "systemctl restart ultra-api 2>/dev/null || systemctl restart ultra_server 2>/dev/null || true"

sleep 2
curl -sS "https://api.ultra.winagrum.tech/health" || true
"${REPO_ROOT}/scripts/live_api_test.sh" || true
rm -f "$KEY_FILE"
echo "Backup: /root/${BACKUP_NAME}"
