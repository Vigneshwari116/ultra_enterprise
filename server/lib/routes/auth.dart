import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../auth/client_ip.dart';
import '../auth/login_rate_limiter.dart';
import '../auth/password_hash.dart';
import '../auth/principal.dart';
import '../auth/session_store.dart';
import '../auth/tokens.dart';
import '../http.dart';

const _invalidLogin = 'Invalid username or password';
const _uuid = Uuid();

void registerAuthRoutes(Router router, Connection conn) {
  final store = SessionStore(conn);

  router.post('/api/auth/login', (Request request) async {
    return _login(request, store);
  });

  router.post('/api/auth/logout', (Request request) async {
    final principal = principalOf(request);
    if (principal == null) return jsonError('Unauthorized', status: 401);
    await store.endSession(principal.sessionId, 'user');
    return jsonOk({'ok': true});
  });

  router.get('/api/auth/me', (Request request) async {
    final principal = principalOf(request);
    if (principal == null) return jsonError('Unauthorized', status: 401);
    return jsonOk({
      'session_id': principal.sessionId,
      'user': principal.toJson(),
    });
  });
}

Future<Response> _login(Request request, SessionStore store) async {
  final Map<String, dynamic> body;
  try {
    body = await readJsonObject(request);
  } on FormatException {
    return jsonError('JSON object required');
  }

  final username = '${body['username'] ?? ''}'.trim();
  final password = body['password'];
  final passwordText = password is String ? password : '';
  if (username.isEmpty || passwordText.isEmpty) {
    return jsonError('username and password are required');
  }

  final ip = clientIp(request);
  if (loginRateLimiter.isBlocked(username: username, ip: ip)) {
    return jsonError(
      'Too many login attempts. Try again later.',
      status: 429,
    );
  }

  final user = await store.findUserByUsername(username);
  final passwordOk = verifyPassword(
    passwordText,
    user == null ? _dummyHash() : user.passwordHash,
  );
  if (user == null || !passwordOk || !user.isActive) {
    loginRateLimiter.recordFailure(username: username, ip: ip);
    return jsonError(_invalidLogin, status: 401);
  }

  final device = '${body['device_name'] ?? ''}'.trim();
  final token = newSessionToken();
  final sessionId = _uuid.v4();
  await store.createSession(
    id: sessionId,
    userId: user.id,
    tokenHash: sha256Hex(token),
    deviceName: device.isEmpty ? null : _clip(device, 200),
    ipAddress: ip.isEmpty ? null : _clip(ip, 200),
  );

  return jsonOk({
    'token': token,
    'session_id': sessionId,
    'user': {
      'id': user.id,
      'username': user.username,
      'name': user.name,
      'role': user.role,
    },
  });
}

String _clip(String value, int max) {
  if (value.length <= max) return value;
  return value.substring(0, max);
}

String? _cachedDummyHash;

String _dummyHash() => _cachedDummyHash ??= hashPassword('not-a-real-password');
