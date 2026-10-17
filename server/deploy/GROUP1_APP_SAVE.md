# Group 1 — save one bill from the Flutter app

Changes: `API_BASE_URL` / `ULTRA_API_URL` dart-define, server-owned voucher numbers, sales/purchase round-off up to ₹1 on the server, readable API error dialogs.

## API container (if not already running)

From `/root/ultra_api_test/server` — use your existing compose/Docker flow so the app can reach `http://127.0.0.1:3004` (or your mapped port).

## Server integration tests (`ultra_copy_test` only)

```bash
export TEST_DATABASE_URL='postgresql://USER:PASS@127.0.0.1:55432/ultra_copy_test?sslmode=disable'

docker run --rm --network host \
  -v /root/ultra_api_test:/app \
  -w /app/server \
  -e TEST_DATABASE_URL \
  dart:3.5.4 bash -lc '
    apt-get update -qq && apt-get install -y -qq postgresql-client >/dev/null
    dart pub get
    dart test test/vps_integration_test.dart --reporter expanded -n "round-off"
  '
```

## Flutter app — point at VPS test API

Build/run with **`API_BASE_URL`** (no trailing slash). Example: API on loopback **3004**.

**Linux desktop (on a machine with Flutter SDK):**

```bash
cd /root/ultra_api_test
flutter pub get
flutter analyze
flutter run -d linux \
  --dart-define=API_BASE_URL=http://127.0.0.1:3004
```

**Release APK (same define):**

```bash
cd /root/ultra_api_test
flutter build apk --release \
  --dart-define=API_BASE_URL=http://YOUR_VPS_IP:3004
```

`UltraConfig.persistLocally` is `false` — the app uses the REST API. Sales/purchase screens show **Assigned on save**; the server returns `invoice_no` / `voucher_no` and `voucher_no_display`.

### Save one sales invoice (manual)

1. Open **Sales Invoice**, pick **customer 17**, **Intra State** or **Inter State** zone, add line with **product 983**.
2. **Save & print** — on failure you should get a dialog with the server `error` text (not a raw `Exception:` dump).
3. Confirm in DB:

```bash
docker exec pg-inspect-testing psql -U ultra_app -d ultra_copy -c \
"SELECT id, invoice_no, voucher_no_display, grand_total
 FROM sales_invoices ORDER BY id DESC LIMIT 3;"
```

### Optional runtime override (no rebuild)

In Dart code you can set before `runApp`:

```dart
UltraConfig.apiBaseUrlOverride = 'http://127.0.0.1:3004';
```

(Not wired to a settings UI in Group 1 — compile-time define is the primary path.)
