import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth/auth_middleware.dart';
import 'http.dart';
import 'register_merged_routes.dart';
import 'routes/admin_users.dart';
import 'routes/auth.dart';

/// Shelf handler for `/health`, auth, admin, and the merged business routes.
///
/// Every `/api` route except `POST /api/auth/login` requires
/// `Authorization: Bearer <token>`. Mount this handler rather than calling
/// [registerMergedRoutes] on its own.
Handler buildApiHandler(Connection conn) {
  final router = Router();

  router.get('/health', (_) async {
    final rows = await conn.execute('SELECT current_database() AS name');
    final dbName = '${rows.first.toColumnMap()['name']}';
    return jsonOk({'ok': true, 'database': dbName});
  });

  registerAuthRoutes(router, conn);
  registerAdminRoutes(router, conn);
  registerMergedRoutes(router, conn);

  return const Pipeline()
      .addMiddleware(apiAuthMiddleware(conn))
      .addHandler(router.call);
}
