import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:ultra_api_server/register_merged_routes.dart';
import 'package:ultra_api_server/routes/products.dart';
import 'package:ultra_api_server/routes/units.dart';

void main() {
  group('unit validation', () {
    test('rejects missing code', () {
      expect(validateUnitBody({'name': 'Kilogram'}), 'code is required');
    });

    test('rejects missing name and description', () {
      expect(validateUnitBody({'code': 'KG'}), 'name or description is required');
    });

    test('accepts code with description only', () {
      expect(validateUnitBody({'code': 'KG', 'description': 'Kilogram'}), isNull);
    });
  });

  group('product validation', () {
    test('create requires product_name', () {
      expect(
        validateProductBody({'unit_id': 1}, isCreate: true),
        'product_name is required',
      );
    });

    test('create requires unit_id', () {
      expect(
        validateProductBody({'product_name': 'Widget'}, isCreate: true),
        'unit_id is required',
      );
    });

    test('rejects invalid unit_id type', () {
      expect(
        validateProductBody({'product_name': 'W', 'unit_id': 'abc'}, isCreate: true),
        'unit_id must be a number',
      );
    });

    test('update allows partial body', () {
      expect(validateProductBody({'product_name': 'Renamed'}, isCreate: false), isNull);
    });
  });

  final dbUrl = Platform.environment['TEST_DATABASE_URL'] ?? Platform.environment['DATABASE_URL'];

  group('units and products routes (PostgreSQL)', () {
    if (dbUrl == null || dbUrl.isEmpty) {
      test('skipped without TEST_DATABASE_URL', () {}, skip: 'Set TEST_DATABASE_URL');
      return;
    }

    late Connection conn;

    setUpAll(() async {
      conn = await Connection.openFromUrl(dbUrl);
      await conn.execute('''
        CREATE TABLE IF NOT EXISTS units (
          id SERIAL PRIMARY KEY,
          code TEXT NOT NULL,
          name TEXT NOT NULL,
          description TEXT,
          is_active BOOLEAN DEFAULT true,
          created_at TIMESTAMPTZ DEFAULT NOW()
        )
      ''');
      await conn.execute('''
        CREATE TABLE IF NOT EXISTS products (
          id SERIAL PRIMARY KEY,
          uuid UUID,
          product_code TEXT,
          product_name TEXT NOT NULL,
          unit_id INTEGER REFERENCES units(id),
          material_type_id INTEGER,
          hsn_code TEXT,
          sales_rate NUMERIC DEFAULT 0,
          purchase_rate NUMERIC DEFAULT 0,
          gst_rate NUMERIC,
          reorder_level NUMERIC DEFAULT 0,
          is_active BOOLEAN DEFAULT true,
          current_stock NUMERIC DEFAULT 0,
          opening_stock NUMERIC DEFAULT 0,
          created_at TIMESTAMPTZ DEFAULT NOW()
        )
      ''');
    });

    tearDown(() async {
      await conn.execute('DELETE FROM products');
      await conn.execute('DELETE FROM units');
    });

    tearDownAll(() async {
      await conn.close();
    });

    Future<Response> call(String method, String path, {String? body}) async {
      final router = Router();
      registerMergedRoutes(router, conn);
      return router.call(
        Request(
          method,
          Uri.parse('http://127.0.0.1$path'),
          headers: body != null ? {'content-type': 'application/json'} : null,
          body: body,
        ),
      );
    }

    test('POST unit validation failure', () async {
      final response = await call('POST', '/api/units', body: '{}');
      expect(response.statusCode, 400);
    });

    test('unit create, update, safe delete, and GET list', () async {
      final create = await call(
        'POST',
        '/api/units',
        body: jsonEncode({'code': 'TST', 'name': 'Test unit', 'description': 'Test'}),
      );
      expect(create.statusCode, 201);
      final createBody = jsonDecode(await create.readAsString()) as Map;
      final unitId = createBody['id'];

      final listAfterCreate = await call('GET', '/api/units');
      expect(listAfterCreate.statusCode, 200);
      final units = jsonDecode(await listAfterCreate.readAsString()) as List;
      expect(units.any((u) => u['id'] == unitId && u['code'] == 'TST'), isTrue);

      final update = await call(
        'PUT',
        '/api/units/$unitId',
        body: jsonEncode({'code': 'TST', 'name': 'Test unit renamed', 'description': 'Test'}),
      );
      expect(update.statusCode, 200);

      final listAfterUpdate = await call('GET', '/api/units');
      final units2 = jsonDecode(await listAfterUpdate.readAsString()) as List;
      final row = units2.firstWhere((u) => u['id'] == unitId) as Map;
      expect(row['name'], 'Test unit renamed');

      final del = await call('DELETE', '/api/units/$unitId');
      expect(del.statusCode, 200);
      final delBody = jsonDecode(await del.readAsString()) as Map;
      expect(delBody['deleted'], true);

      final listAfterDelete = await call('GET', '/api/units');
      final units3 = jsonDecode(await listAfterDelete.readAsString()) as List;
      expect(units3.any((u) => u['id'] == unitId), isFalse);
    });

    test('unit delete deactivates when referenced by a product', () async {
      final unitRes = await call(
        'POST',
        '/api/units',
        body: jsonEncode({'code': 'REF', 'name': 'Referenced'}),
      );
      final unitId = (jsonDecode(await unitRes.readAsString()) as Map)['id'];

      final productRes = await call(
        'POST',
        '/api/products',
        body: jsonEncode({
          'product_name': 'Linked product',
          'barcode': 'REF-001',
          'unit_id': unitId,
          'hsn': '1234',
          'sales_rate': 10,
        }),
      );
      expect(productRes.statusCode, 201);

      final del = await call('DELETE', '/api/units/$unitId');
      expect(del.statusCode, 200);
      final delBody = jsonDecode(await del.readAsString()) as Map;
      expect(delBody['deactivated'], true);

      final listUnits = jsonDecode(await (await call('GET', '/api/units')).readAsString()) as List;
      final unitRow = listUnits.firstWhere((u) => u['id'] == unitId) as Map;
      expect(unitRow['is_active'], false);
    });

    test('product create, update, validation, and GET list', () async {
      final unitRes = await call(
        'POST',
        '/api/units',
        body: jsonEncode({'code': 'PCS', 'name': 'Pieces'}),
      );
      final unitId = (jsonDecode(await unitRes.readAsString()) as Map)['id'];

      final bad = await call('POST', '/api/products', body: '{}');
      expect(bad.statusCode, 400);

      final create = await call(
        'POST',
        '/api/products',
        body: jsonEncode({
          'product_name': 'New material',
          'barcode': 'MAT-100',
          'unit_id': unitId,
          'hsn': '8471',
          'sales_rate': 99.5,
        }),
      );
      expect(create.statusCode, 201);
      final productId = (jsonDecode(await create.readAsString()) as Map)['id'];

      final listCreate = jsonDecode(await (await call('GET', '/api/products')).readAsString()) as List;
      expect(
        listCreate.any((p) => p['id'] == productId && p['product_name'] == 'New material'),
        isTrue,
      );

      final update = await call(
        'PUT',
        '/api/products/$productId',
        body: jsonEncode({'product_name': 'Renamed material', 'sales_rate': 120}),
      );
      expect(update.statusCode, 200);

      final listUpdate = jsonDecode(await (await call('GET', '/api/products')).readAsString()) as List;
      final product = listUpdate.firstWhere((p) => p['id'] == productId) as Map;
      expect(product['product_name'], 'Renamed material');
    });
  });
}
