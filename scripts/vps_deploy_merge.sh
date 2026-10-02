#!/usr/bin/env bash
# Merge missing Ultra API routes into the existing VPS Dart server at /root/ultra_server.
# Does NOT replace the whole server — copies route modules and registers handlers only.
#
# Required env:
#   VPS_SSH_PRIVATE_KEY — PEM private key for root@VPS_HOST
# Optional:
#   VPS_HOST (default 187.127.180.135)
#   ULTRA_SERVER_DIR (default /root/ultra_server)
#   API_PORT (default 8081) — used for post-deploy curl checks only

set -euo pipefail

VPS_HOST="${VPS_HOST:-187.127.180.135}"
ULTRA_SERVER_DIR="${ULTRA_SERVER_DIR:-/root/ultra_server}"
API_PORT="${API_PORT:-8081}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY_FILE="${TMPDIR:-/tmp}/vps_deploy_key_$$"

if [[ -z "${VPS_SSH_PRIVATE_KEY:-}" ]]; then
  echo "ERROR: VPS_SSH_PRIVATE_KEY is not set. Add it to Cloud Agent secrets and re-run." >&2
  exit 1
fi

umask 077
printf '%s\n' "$VPS_SSH_PRIVATE_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

SSH=(ssh -i "$KEY_FILE" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "root@${VPS_HOST}")
SCP=(scp -i "$KEY_FILE" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

BACKUP_NAME="ultra_server_backup_$(date -u +%Y%m%d_%H%M%S)"
echo "=== 1) Backup ${ULTRA_SERVER_DIR} -> /root/${BACKUP_NAME} ==="
"${SSH[@]}" "cp -a '${ULTRA_SERVER_DIR}' '/root/${BACKUP_NAME}' && echo Backup OK: /root/${BACKUP_NAME}"

echo "=== 2) Inspect current routes (grep) ==="
"${SSH[@]}" "cd '${ULTRA_SERVER_DIR}' && grep -R \"router\\.\(get\\|post\\|put\\|delete\\)\" -n lib bin 2>/dev/null | head -80 || true"

echo "=== 3) Upload route modules from ${REPO_ROOT}/server/lib ==="
"${SSH[@]}" "mkdir -p '${ULTRA_SERVER_DIR}/lib/routes'"
"${SCP[@]}" "${REPO_ROOT}/server/lib/json_util.dart" "root@${VPS_HOST}:${ULTRA_SERVER_DIR}/lib/json_util.dart"
for f in purchase_vouchers.dart masters.dart; do
  "${SCP[@]}" "${REPO_ROOT}/server/lib/routes/${f}" "root@${VPS_HOST}:${ULTRA_SERVER_DIR}/lib/routes/${f}"
done

echo "=== 4) Register routes (idempotent marker QA_MERGE_ROUTES) ==="
"${SSH[@]}" bash -s <<'REMOTE'
set -euo pipefail
cd "$ULTRA_SERVER_DIR"
MARKER="QA_MERGE_ROUTES"
if grep -q "$MARKER" lib/routes/qa_merge_register.dart 2>/dev/null; then
  echo "Register file already present"
else
  cat > lib/routes/qa_merge_register.dart <<'DART'
// QA_MERGE_ROUTES — auto-merged missing REST handlers (do not remove working SI/PV POST).
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../json_util.dart';
import 'masters.dart';
import 'purchase_vouchers.dart';

void registerQaMergedRoutes(Router router, Connection conn) {
  router.get('/api/purchase-vouchers/<id>', (Request request, String id) async {
    final vid = int.tryParse(id);
    if (vid == null) {
      return Response(400, body: '{"error":"Invalid purchase voucher id"}');
    }
    return getPurchaseVoucherById(conn, vid);
  });

  router.post('/api/customers', (r) => createCustomer(r, conn));
  router.put('/api/customers/<id>', (Request r, String id) async {
    final cid = int.tryParse(id);
    if (cid == null) return Response(400, body: '{"error":"Invalid customer id"}');
    return updateCustomer(r, conn, cid);
  });

  router.get('/api/suppliers/<id>', (Request _, String id) async {
    final sid = int.tryParse(id);
    if (sid == null) return Response(400, body: '{"error":"Invalid supplier id"}');
    return getSupplier(conn, sid);
  });
  router.post('/api/suppliers', (r) => createSupplier(r, conn));
  router.put('/api/suppliers/<id>', (Request r, String id) async {
    final sid = int.tryParse(id);
    if (sid == null) return Response(400, body: '{"error":"Invalid supplier id"}');
    return updateSupplier(r, conn, sid);
  });
}
DART
fi

# Wire into main router: append call after Connection is available.
MAIN=""
for candidate in bin/server.dart lib/main.dart lib/api.dart; do
  [[ -f "$candidate" ]] && MAIN="$candidate" && break
done
if [[ -z "$MAIN" ]]; then
  echo "ERROR: Could not find server entry dart file under $ULTRA_SERVER_DIR" >&2
  exit 1
fi
echo "Main entry: $MAIN"

if ! grep -q 'registerQaMergedRoutes' "$MAIN"; then
  if ! grep -q "import 'routes/qa_merge_register.dart'" "$MAIN" && ! grep -q 'routes/qa_merge_register.dart' "$MAIN"; then
    sed -i "1i import 'routes/qa_merge_register.dart';" "$MAIN" 2>/dev/null || true
  fi
  echo "MANUAL: add registerQaMergedRoutes(router, conn); after router/conn setup in $MAIN"
fi
REMOTE

echo "=== 5) dart pub get && compile check ==="
"${SSH[@]}" "cd '${ULTRA_SERVER_DIR}' && dart pub get && dart analyze 2>&1 | tail -20"

echo "=== 6) Restart API (systemd or pkill) ==="
"${SSH[@]}" "systemctl restart ultra-api 2>/dev/null || systemctl restart ultra_server 2>/dev/null || (pkill -f 'dart.*${ULTRA_SERVER_DIR}' || true; sleep 1; nohup dart run bin/server.dart >> /var/log/ultra_api.log 2>&1 &)"

sleep 3
echo "=== 7) Health ==="
curl -sS "https://api.ultra.winagrum.tech/health"
echo
"${REPO_ROOT}/scripts/live_api_test.sh"

rm -f "$KEY_FILE"
echo "Done. Backup: /root/${BACKUP_NAME}"
