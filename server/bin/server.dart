import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:ultra_api_server/env.dart';
import 'package:ultra_api_server/routes/masters.dart';
import 'package:ultra_api_server/routes/purchase_vouchers.dart';

Future<void> main() async {
  final conn = await Connection.openFromUrl(Env.databaseUrl);
  final router = Router();

  router.get('/health', (_) {
    return Response.ok(
      jsonEncode({'ok': true, 'database': 'ultra_enterprise'}),
      headers: {'content-type': 'application/json'},
    );
  });

  router.get('/api/purchase-vouchers/<id>', (Request request, String id) async {
    final vid = int.tryParse(id);
    if (vid == null) {
      return Response(400, body: '{"error":"Invalid purchase voucher id"}');
    }
    return getPurchaseVoucherById(conn, vid);
  });

  router.get('/api/customers', (_) => listCustomers(conn));
  router.post('/api/customers', (r) => createCustomer(r, conn));
  router.put('/api/customers/<id>', (Request r, String id) async {
    final cid = int.tryParse(id);
    if (cid == null) return Response(400, body: '{"error":"Invalid customer id"}');
    return updateCustomer(r, conn, cid);
  });

  router.get('/api/suppliers', (_) => listSuppliers(conn));
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

  final handler = const Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, Env.port);
  stdout.writeln('Ultra API listening on http://${server.address.host}:${server.port}');
}
