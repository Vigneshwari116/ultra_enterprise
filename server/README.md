# Ultra API Server (Dart Shelf)

This package implements the REST routes required by `lib/services/ultra_repository.dart` against the PostgreSQL database **`ultra_enterprise`**.

The production host `https://api.ultra.winagrum.tech` already runs a Dart Shelf build with a subset of routes. Deploy this package (or merge `lib/routes.dart` into your existing VPS server) and restart the service so missing endpoints return real data instead of `Route not found`.

## Configure

```bash
export DATABASE_URL='postgresql://user:pass@host:5432/ultra_enterprise'
export PORT=8080
cd server
dart pub get
dart run bin/server.dart
```

## Priority route: purchase voucher detail

`GET /api/purchase-vouchers/<id>` must return:

```json
{
  "voucher": { "id", "voucher_no", "supplier_name", "taxable_total", ... },
  "items": [ { "product_id", "quantity", "rate", "taxable", "cgst", ... } ]
}
```

Implementation: `lib/routes/purchase_vouchers.dart` (`getPurchaseVoucherById`).

## Verify after deploy

```bash
./scripts/live_api_test.sh
```
