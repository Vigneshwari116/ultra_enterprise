# Ultra API — merged route package

Dart Shelf handlers for REST routes that the Flutter app expects but are **not** yet on `https://api.ultra.winagrum.tech`.

## Design

- **`registerMergedRoutes(router, conn)`** in `lib/register_merged_routes.dart` registers **only missing routes**.
- Does **not** register `POST /api/sales-invoices` or `POST /api/purchase-vouchers` (already implemented on the VPS).
- Adds **units** (`POST`, `PUT`, `DELETE`) and **products** (`POST`, `PUT`) write routes plus matching `GET` list handlers for local dev (VPS may already serve `GET`; register merge after existing routes so production list behavior stays unchanged).
- Uses PostgreSQL transactions (`conn.runTx`) for multi-table saves.
- Supplier party names are read from envelope `suppliers.data` JSON (`data::jsonb->>'supplier_name'`).

## VPS merge (when SSH is available)

1. Backup `/root/ultra_server`.
2. Copy `server/lib/**` into the VPS project `lib/`.
3. In the existing server entry (`bin/server.dart` or `lib/api.dart`), after `Connection` and `Router` exist:

```dart
import 'register_merged_routes.dart';

registerMergedRoutes(router, conn);
```

4. `dart pub get`, `dart analyze`, restart systemd service on port **8081**.

Or run from repo root: `./scripts/vps_deploy_merge.sh` (requires `VPS_SSH_PRIVATE_KEY`).

## Local run (full merged routes only)

```bash
export DATABASE_URL='postgresql://.../ultra_enterprise'
cd server && dart pub get && dart run bin/server.dart
```

## Tests

```bash
cd server && dart test
```

Set `TEST_DATABASE_URL` for PostgreSQL handler integration tests (otherwise skipped).
