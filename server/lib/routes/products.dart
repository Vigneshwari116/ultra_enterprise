import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../db_errors.dart';
import '../http.dart';

const _uuid = Uuid();

/// Validates product create/update JSON. Returns an error message or null if valid.
String? validateProductBody(Map<String, dynamic> body, {required bool isCreate}) {
  if (isCreate && '${body['product_name'] ?? ''}'.trim().isEmpty) {
    return 'product_name is required';
  }
  if (isCreate && body['unit_id'] == null) {
    return 'unit_id is required';
  }
  if (body['unit_id'] != null) {
    final unitId = body['unit_id'];
    if (unitId is! num && int.tryParse('$unitId') == null) {
      return 'unit_id must be a number';
    }
  }
  return null;
}

void registerProductRoutes(Router router, Connection conn) {
  router.get('/api/products', (_) => listProducts(conn));
  router.post('/api/products', (r) => createProduct(r, conn));
  router.put('/api/products/<id>', (Request r, String id) async {
    final pid = int.tryParse(id);
    if (pid == null) return jsonError('Invalid product id', status: 400);
    return updateProduct(r, conn, pid);
  });
}

/// Matches live `GET /api/products` (active products with UOM code).
Future<Response> listProducts(Connection conn) async {
  final rows = await conn.execute('''
    SELECT
      p.id,
      p.uuid,
      p.product_code,
      p.product_name,
      p.unit_id,
      COALESCE(u.code, '') AS uom_code,
      p.hsn_code,
      p.material_type_id,
      p.sales_rate,
      p.purchase_rate,
      p.gst_rate,
      p.reorder_level,
      p.is_active,
      COALESCE(st.quantity, 0) AS current_stock
    FROM products p
    LEFT JOIN units u ON u.id = p.unit_id
    LEFT JOIN stock st ON st.product_id = p.id
    WHERE p.is_active = true
    ORDER BY p.id
  ''');
  return jsonOk(serializeRows(rows.map((r) => r.toColumnMap()).toList()));
}

Future<Response> createProduct(Request request, Connection conn) async {
  final body = await readJsonObject(request);
  final validation = validateProductBody(body, isCreate: true);
  if (validation != null) return jsonError(validation);

  final unitId = _asInt(body['unit_id']);
  if (unitId == null) return jsonError('unit_id is required');

  final unitOk = await conn.execute(
    Sql.named('SELECT id FROM units WHERE id = @id'),
    parameters: {'id': unitId},
  );
  if (unitOk.isEmpty) return jsonError('unit_id not found: $unitId', status: 400);

  final materialTypeError = await _validateMaterialTypeId(conn, body);
  if (materialTypeError != null) return jsonError(materialTypeError);

  final productCode = _productCodeFromBody(body);
  final params = _productWriteParams(body, productCode: productCode, unitId: unitId);
  final stockQty = _stockQuantityFromBody(body, defaultZero: true) ?? 0;

  try {
    final id = await conn.runTx((tx) async {
      final result = await tx.execute(
        Sql.named('''
          INSERT INTO products (
            uuid, product_code, product_name, unit_id,
            hsn_code, material_type_id, sales_rate, purchase_rate, gst_rate,
            reorder_level, is_active, created_at
          ) VALUES (
            @uuid, @product_code, @product_name, @unit_id,
            @hsn_code, @material_type_id, @sales_rate, @purchase_rate, @gst_rate,
            @reorder_level, true, NOW()
          )
          RETURNING id
        '''),
        parameters: {
          'uuid': _uuid.v4(),
          ...params,
          'reorder_level': body['reorder_level'] ?? 0,
        },
      );
      final productId = result.first.first as int;
      await _upsertStock(tx, productId, stockQty);
      return productId;
    });
    return jsonOk({'id': id, 'product': {'id': id}}, status: 201);
  } catch (e) {
    if (isPostgresUniqueViolation(e)) {
      return jsonError('Product code already exists', status: 409);
    }
    rethrow;
  }
}

Future<Response> updateProduct(Request request, Connection conn, int id) async {
  final body = await readJsonObject(request);
  final validation = validateProductBody(body, isCreate: false);
  if (validation != null) return jsonError(validation);

  if (body['unit_id'] != null) {
    final unitId = _asInt(body['unit_id']);
    if (unitId == null) return jsonError('unit_id must be a number');
    final unitOk = await conn.execute(
      Sql.named('SELECT id FROM units WHERE id = @id'),
      parameters: {'id': unitId},
    );
    if (unitOk.isEmpty) return jsonError('unit_id not found: $unitId', status: 400);
  }

  if (body.containsKey('material_type_id')) {
    final materialTypeError = await _validateMaterialTypeId(conn, body);
    if (materialTypeError != null) return jsonError(materialTypeError);
  }

  final productCode = body.containsKey('barcode') || body.containsKey('product_code')
      ? _productCodeFromBody(body)
      : null;

  final hasStockUpdate =
      body.containsKey('current_stock') || body.containsKey('opening_stock');

  final updated = await conn.runTx((tx) async {
    final rows = await tx.execute(
      Sql.named('''
        UPDATE products SET
          product_code = COALESCE(@product_code, product_code),
          product_name = COALESCE(@product_name, product_name),
          unit_id = COALESCE(@unit_id, unit_id),
          hsn_code = COALESCE(@hsn_code, hsn_code),
          material_type_id = COALESCE(@material_type_id, material_type_id),
          sales_rate = COALESCE(@sales_rate, sales_rate),
          purchase_rate = COALESCE(@purchase_rate, purchase_rate),
          gst_rate = COALESCE(@gst_rate, gst_rate),
          reorder_level = COALESCE(@reorder_level, reorder_level),
          updated_at = NOW()
        WHERE id = @id AND is_active = true
        RETURNING id
      '''),
      parameters: {
        'id': id,
        'product_code': productCode,
        'product_name': body['product_name'],
        'unit_id': _asInt(body['unit_id']),
        'hsn_code': _hsnFromBody(body),
        'material_type_id': body.containsKey('material_type_id')
            ? _asInt(body['material_type_id'])
            : null,
        'sales_rate': body.containsKey('sales_rate') || body.containsKey('rate')
            ? _num(body['sales_rate'] ?? body['rate'])
            : null,
        'purchase_rate':
            body.containsKey('purchase_rate') ? _num(body['purchase_rate']) : null,
        'gst_rate': body.containsKey('gst_rate') ? _num(body['gst_rate']) : null,
        'reorder_level': _num(body['reorder_level']),
      },
    );
    if (rows.isEmpty) return false;

    if (hasStockUpdate) {
      final qty = _stockQuantityFromBody(body, defaultZero: false);
      if (qty != null) {
        await _upsertStock(tx, id, qty);
      }
    }
    return true;
  });

  if (!updated) {
    return jsonError('Product not found or inactive: $id', status: 404);
  }
  return jsonOk({'id': id, 'product': {'id': id}});
}

Future<void> _upsertStock(Session session, int productId, num quantity) async {
  await session.execute(
    Sql.named('''
      INSERT INTO stock (product_id, quantity)
      VALUES (@product_id, @quantity)
      ON CONFLICT (product_id)
      DO UPDATE SET quantity = EXCLUDED.quantity, updated_at = NOW()
    '''),
    parameters: {'product_id': productId, 'quantity': quantity},
  );
}

/// Stock quantity from API body (`current_stock` or `opening_stock`).
/// When [defaultZero] is true, missing keys yield 0 (create path).
num? _stockQuantityFromBody(Map<String, dynamic> body, {required bool defaultZero}) {
  if (body.containsKey('current_stock') || body.containsKey('opening_stock')) {
    return _num(body['current_stock'] ?? body['opening_stock']) ?? 0;
  }
  return defaultZero ? 0 : null;
}

Map<String, dynamic> _productWriteParams(
  Map<String, dynamic> body, {
  required String? productCode,
  required int unitId,
}) {
  return {
    'product_code': productCode,
    'product_name': body['product_name'],
    'unit_id': unitId,
    'hsn_code': _hsnFromBody(body),
    'material_type_id': _asInt(body['material_type_id']),
    'sales_rate': _num(body['sales_rate'] ?? body['rate']) ?? 0,
    'purchase_rate': _num(body['purchase_rate']) ?? 0,
    'gst_rate': _num(body['gst_rate']),
  };
}

Future<String?> _validateMaterialTypeId(Connection conn, Map<String, dynamic> body) async {
  if (!body.containsKey('material_type_id') || body['material_type_id'] == null) {
    return null;
  }
  final materialTypeId = _asInt(body['material_type_id']);
  if (materialTypeId == null) return 'material_type_id must be a number';
  final rows = await conn.execute(
    Sql.named('SELECT id FROM material_types WHERE id = @id'),
    parameters: {'id': materialTypeId},
  );
  if (rows.isEmpty) return 'material_type_id not found: $materialTypeId';
  return null;
}

String? _productCodeFromBody(Map<String, dynamic> body) {
  final code = '${body['product_code'] ?? body['barcode'] ?? ''}'.trim();
  return code.isEmpty ? null : code;
}

String? _hsnFromBody(Map<String, dynamic> body) {
  final hsn = '${body['hsn'] ?? body['hsn_code'] ?? ''}'.trim();
  return hsn.isEmpty ? null : hsn;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value'.trim());
}

num? _num(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse('$value'.trim());
}
