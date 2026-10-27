import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/db_values.dart';
import '../auth/password_hash.dart';
import '../auth/principal.dart';
import '../auth/session_store.dart';
import '../db_errors.dart';
import '../http.dart';

void registerAdminRoutes(Router router, Connection conn) {
  final store = SessionStore(conn);

  router.get('/api/admin/sessions', (Request request) {
    return _sessions(request, store);
  });
  router.post('/api/admin/sessions/<id>/logout', (Request request, String id) {
    return _logoutSession(request, store, id);
  });
  router.post('/api/admin/users/<id>/logout-all', (Request request, String id) {
    return _logoutAll(request, store, id);
  });
  router.get('/api/admin/users', (Request request) {
    return _listUsers(request, store);
  });
  router.post('/api/admin/users', (Request request) {
    return _createUser(request, store);
  });
  router.put('/api/admin/users/<id>', (Request request, String id) {
    return _updateUser(request, store, id);
  });
}

Response? _adminOnly(Request request) {
  final principal = principalOf(request);
  if (principal == null) return jsonError('Unauthorized', status: 401);
  if (!principal.isAdmin) return jsonError('Forbidden', status: 403);
  return null;
}

Future<Response> _sessions(Request request, SessionStore store) async {
  final denied = _adminOnly(request);
  if (denied != null) return denied;

  final params = request.requestedUri.queryParameters;
  final status = (params['status'] ?? '').trim();
  if (status != 'online' && status != 'history') {
    return jsonError('status must be online or history');
  }
  String? dateFrom;
  String? dateTo;
  if (status == 'history') {
    final fromRaw = params['date_from']?.trim();
    final toRaw = params['date_to']?.trim();
    if (fromRaw != null && fromRaw.isNotEmpty) {
      if (_date(fromRaw) == null) return jsonError('date_from must be YYYY-MM-DD');
      dateFrom = fromRaw;
    }
    if (toRaw != null && toRaw.isNotEmpty) {
      if (_date(toRaw) == null) return jsonError('date_to must be YYYY-MM-DD');
      dateTo = toRaw;
    }
  }

  final sessions = serializeRows(await store.listSessions(
    onlineOnly: status == 'online',
    dateFrom: dateFrom,
    dateTo: dateTo,
  ));
  return jsonOk({
    'online_user_count': await store.onlineUserCount(),
    'sessions': sessions,
  });
}

Future<Response> _logoutSession(Request request, SessionStore store, String id) async {
  final denied = _adminOnly(request);
  if (denied != null) return denied;
  if (!_uuid(id)) return jsonError('Invalid session id', status: 400);
  if (!await store.sessionExists(id)) {
    return jsonError('Session not found', status: 404);
  }
  await store.endSession(id, 'admin');
  return jsonOk({'ok': true});
}

Future<Response> _logoutAll(Request request, SessionStore store, String id) async {
  final denied = _adminOnly(request);
  if (denied != null) return denied;
  final userId = int.tryParse(id);
  if (userId == null) return jsonError('Invalid user id', status: 400);
  final user = await store.findUserById(userId);
  if (user == null) return jsonError('User not found', status: 404);
  final ended = await store.endSessionsForUser(userId, 'admin');
  return jsonOk({'ok': true, 'ended': ended});
}

Future<Response> _listUsers(Request request, SessionStore store) async {
  final denied = _adminOnly(request);
  if (denied != null) return denied;
  return jsonOk({
    'online_user_count': await store.onlineUserCount(),
    'users': serializeRows(await store.listUsers()),
  });
}

Future<Response> _createUser(Request request, SessionStore store) async {
  final denied = _adminOnly(request);
  if (denied != null) return denied;
  final Map<String, dynamic> body;
  try {
    body = await readJsonObject(request);
  } on FormatException {
    return jsonError('JSON object required');
  }

  final username = '${body['username'] ?? ''}'.trim();
  final name = '${body['name'] ?? ''}'.trim();
  final role = '${body['role'] ?? ''}'.trim();
  final password = body['password'];
  final passwordText = password is String ? password : '';
  if (username.isEmpty || name.isEmpty || passwordText.isEmpty) {
    return jsonError('username, name, and password are required');
  }
  if (username.length > 100) return jsonError('username is too long');
  if (name.length > 200) return jsonError('name is too long');
  if (!userRoles.contains(role)) {
    return jsonError("role must be superuser, admin, or user");
  }
  final passwordError = _passwordError(passwordText);
  if (passwordError != null) return jsonError(passwordError);

  try {
    final id = await store.insertUser(
      username: username,
      name: name,
      passwordHash: hashPassword(passwordText),
      role: role,
    );
    final created = await store.findUserById(id);
    return jsonOk({'user': _publicUser(created!)}, status: 201);
  } catch (error) {
    if (isPostgresUniqueViolation(error)) {
      return jsonError('Username already exists', status: 409);
    }
    rethrow;
  }
}

Future<Response> _updateUser(Request request, SessionStore store, String id) async {
  final denied = _adminOnly(request);
  if (denied != null) return denied;
  final userId = int.tryParse(id);
  if (userId == null) return jsonError('Invalid user id', status: 400);

  final Map<String, dynamic> body;
  try {
    body = await readJsonObject(request);
  } on FormatException {
    return jsonError('JSON object required');
  }

  String? name;
  if (body.containsKey('name')) {
    name = '${body['name'] ?? ''}'.trim();
    if (name.isEmpty) return jsonError('name is required');
    if (name.length > 200) return jsonError('name is too long');
  }
  String? role;
  if (body.containsKey('role')) {
    role = '${body['role'] ?? ''}'.trim();
    if (!userRoles.contains(role)) {
      return jsonError('role must be superuser, admin, or user');
    }
  }
  bool? isActive;
  if (body.containsKey('is_active')) {
    isActive = parseBool(body['is_active']);
    if (isActive == null) return jsonError('is_active must be true or false');
  }
  String? passwordHash;
  if (body.containsKey('password')) {
    final password = body['password'];
    final passwordText = password is String ? password : '';
    if (passwordText.isEmpty) return jsonError('password is required');
    final passwordError = _passwordError(passwordText);
    if (passwordError != null) return jsonError(passwordError);
    passwordHash = hashPassword(passwordText);
  }

  if (name == null && role == null && isActive == null && passwordHash == null) {
    return jsonError('No changes');
  }

  final result = await store.updateUser(
    id: userId,
    name: name,
    role: role,
    isActive: isActive,
    passwordHash: passwordHash,
  );
  if (result == 'not_found') return jsonError('User not found', status: 404);
  if (result == 'last_superuser') {
    return jsonError(
      'Cannot disable or demote the last active superuser',
      status: 409,
    );
  }
  final updated = await store.findUserById(userId);
  return jsonOk({'user': _publicUser(updated!)});
}

Map<String, Object?> _publicUser(AppUserRow user) => {
      'id': user.id,
      'username': user.username,
      'name': user.name,
      'role': user.role,
      'is_active': user.isActive,
    };

String? _passwordError(String password) {
  if (passwordByteLength(password) > passwordMaxBytes) {
    return 'Password must be at most $passwordMaxBytes bytes';
  }
  return null;
}

DateTime? _date(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) return null;
  return parsed;
}

bool _uuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}
