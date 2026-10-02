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
      p.reorder_level,
      p.is_active,
      p.current_stock
    FROM products p
    LEFT JOIN units u ON u.id = p.unit_id
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

  final productCode = _productCodeFromBody(body);
  final params = _productWriteParams(body, productCode: productCode, unitId: unitId);

  try {
    final result = await conn.execute(
      Sql.named('''
        INSERT INTO products (
          uuid, product_code, product_name, unit_id, material_type_id,
          hsn_code, sales_rate, purchase_rate, gst_rate,
          reorder_level, is_active, current_stock, opening_stock, created_at
        ) VALUES (
          @uuid, @product_code, @product_name, @unit_id, @material_type_id,
          @hsn_code, @sales_rate, @purchase_rate, @gst_rate,
          @reorder_level, true, @current_stock, @opening_stock, NOW()
        )
        RETURNING id
      '''),
      parameters: {
        'uuid': _uuid.v4(),
        ...params,
        'reorder_level': body['reorder_level'] ?? 0,
        'current_stock': body['current_stock'] ?? body['opening_stock'] ?? 0,
        'opening_stock': body['opening_stock'] ?? 0,
      },
    );
    final id = result.first.first;
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

  final productCode = body.containsKey('barcode') || body.containsKey('product_code')
      ? _productCodeFromBody(body)
      : null;

  final updated = await conn.execute(
    Sql.named('''
      UPDATE products SET
        product_code = COALESCE(@product_code, product_code),
        product_name = COALESCE(@product_name, product_name),
        unit_id = COALESCE(@unit_id, unit_id),
        material_type_id = COALESCE(@material_type_id, material_type_id),
        hsn_code = COALESCE(@hsn_code, hsn_code),
        sales_rate = COALESCE(@sales_rate, sales_rate),
        purchase_rate = COALESCE(@purchase_rate, purchase_rate),
        gst_rate = COALESCE(@gst_rate, gst_rate),
        reorder_level = COALESCE(@reorder_level, reorder_level)
      WHERE id = @id AND is_active = true
      RETURNING id
    '''),
    parameters: {
      'id': id,
      'product_code': productCode,
      'product_name': body['product_name'],
      'unit_id': _asInt(body['unit_id']),
      'material_type_id': _asInt(body['material_type_id']),
      'hsn_code': _hsnFromBody(body),
      'sales_rate': _num(body['sales_rate'] ?? body['rate']),
      'purchase_rate': _num(body['purchase_rate']),
      'gst_rate': _num(body['gst_rate'] ?? body['gst_percent']),
      'reorder_level': _num(body['reorder_level']),
    },
  );
  if (updated.isEmpty) {
    return jsonError('Product not found or inactive: $id', status: 404);
  }
  return jsonOk({'id': id, 'product': {'id': id}});
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
    'material_type_id': _asInt(body['material_type_id']),
    'hsn_code': _hsnFromBody(body),
    'sales_rate': _num(body['sales_rate'] ?? body['rate']) ?? 0,
    'purchase_rate': _num(body['purchase_rate']) ?? 0,
    'gst_rate': _num(body['gst_rate'] ?? body['gst_percent']),
  };
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
