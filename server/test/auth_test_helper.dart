import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:ultra_api_server/api_handler.dart';
import 'package:ultra_api_server/auth/login_rate_limiter.dart';
import 'package:ultra_api_server/auth/password_hash.dart';
import 'package:ultra_api_server/database_connection.dart';

import 'test_fixture_paths.dart';

const String testAdminUsername = 'test_admin';
const String testAdminPassword = 'test-admin-pass';

String databaseNameFromUrl(String url) {
  final path = Uri.parse(url).path;
  if (path.isEmpty || path == '/') return '';
  return Uri.decodeComponent(path.replaceFirst('/', '').split('/').first);
}

/// Refuses production-like databases before any connection is opened.
void assertTestDatabaseUrl(String url) {
  final db = databaseNameFromUrl(url);
  if (db == 'ultra_enterprise' || db == 'ultra_copy') {
    throw StateError('Refusing to connect to database "$db".');
  }
  if (!db.endsWith('_test')) {
    throw StateError(
      'Refusing to run: database "$db" must end with _test '
      '(for example ultra_copy_test).',
    );
  }
}

Future<Connection> openTestDatabase(String url) async {
  assertTestDatabaseUrl(url);
  return openDatabaseFromUrl(url);
}

/// Splits an idempotent SQL file on semicolons. Do not use this for files
/// that contain dollar-quoted function bodies.
Future<void> applyIdempotentSqlFile(Connection conn, String path) async {
  final raw = File(path).readAsStringSync();
  final buf = StringBuffer();
  for (final line in raw.split('\n')) {
    if (line.trimLeft().startsWith('--')) continue;
    buf.writeln(line);
  }
  for (final part in buf.toString().split(';')) {
    final stmt = part.trim();
    if (stmt.isEmpty) continue;
    await conn.execute(stmt);
  }
}

Future<void> ensureAuthTables(Connection conn) async {
  await applyIdempotentSqlFile(
    conn,
    resolveServerRelativePath('schema/migrations/003_users_sessions.sql'),
  );
}

class TestLogin {
  TestLogin({
    required this.token,
    required this.userId,
    required this.sessionId,
    required this.username,
  });

  final String token;
  final int userId;
  final String sessionId;
  final String username;
}

Future<int> insertTestUser(
  Connection conn, {
  required String username,
  required String password,
  String role = 'user',
  String name = 'Test User',
  bool active = true,
}) async {
  await conn.execute(
    Sql.named('''
      DELETE FROM public.app_sessions
      WHERE user_id IN (
        SELECT id FROM public.app_users WHERE LOWER(username) = LOWER(@username)
      )
    '''),
    parameters: {'username': username},
  );
  await conn.execute(
    Sql.named('DELETE FROM public.app_users WHERE LOWER(username) = LOWER(@username)'),
    parameters: {'username': username},
  );
  final rows = await conn.execute(
    Sql.named('''
      INSERT INTO public.app_users (username, name, password_hash, role, is_active)
      VALUES (@username, @name, @password_hash, @role, @is_active)
      RETURNING id
    '''),
    parameters: {
      'username': username,
      'name': name,
      'password_hash': hashPassword(password),
      'role': role,
      'is_active': active,
    },
  );
  final id = rows.first.first;
  if (id is int) return id;
  if (id is BigInt) return id.toInt();
  return int.parse('$id');
}

Future<TestLogin> loginExisting(
  Connection conn, {
  required String username,
  required String password,
  String deviceName = 'test-device',
  Map<String, String>? headers,
}) async {
  final response = await callApi(
    conn,
    'POST',
    '/api/auth/login',
    body: {
      'username': username,
      'password': password,
      'device_name': deviceName,
    },
    headers: headers,
  );
  final raw = await response.readAsString();
  if (response.statusCode != 200) {
    throw StateError('Test login failed (${response.statusCode}): $raw');
  }
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final user = Map<String, dynamic>.from(decoded['user'] as Map);
  final id = user['id'];
  return TestLogin(
    token: '${decoded['token']}',
    userId: id is int ? id : int.parse('$id'),
    sessionId: '${decoded['session_id']}',
    username: '${user['username']}',
  );
}

Future<TestLogin> loginTestUser(
  Connection conn, {
  required String username,
  required String password,
  String role = 'user',
  String name = 'Test User',
  bool active = true,
  String deviceName = 'test-device',
  Map<String, String>? headers,
}) async {
  loginRateLimiter.reset();
  await insertTestUser(
    conn,
    username: username,
    password: password,
    role: role,
    name: name,
    active: active,
  );
  return loginExisting(
    conn,
    username: username,
    password: password,
    deviceName: deviceName,
    headers: headers,
  );
}

Future<TestLogin> loginTestAdmin(Connection conn) {
  return loginTestUser(
    conn,
    username: testAdminUsername,
    password: testAdminPassword,
    role: 'superuser',
    name: 'Test Admin',
    deviceName: 'test-admin',
  );
}

Future<Response> callApi(
  Connection conn,
  String method,
  String path, {
  String? token,
  Object? body,
  Map<String, String>? headers,
}) {
  final headerMap = <String, String>{...?headers};
  if (body != null) headerMap['content-type'] = 'application/json';
  if (token != null && token.isNotEmpty) {
    headerMap['authorization'] = 'Bearer $token';
  }
  return buildApiHandler(conn)(
    Request(
      method,
      Uri.parse('http://127.0.0.1$path'),
      body: body == null ? null : (body is String ? body : jsonEncode(body)),
      headers: headerMap.isEmpty ? null : headerMap,
    ),
  );
}
