import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../http.dart';
import 'principal.dart';
import 'session_store.dart';
import 'tokens.dart';

Middleware apiAuthMiddleware(Connection conn) {
  final store = SessionStore(conn);
  return (Handler inner) {
    return (Request request) async {
      final path = _normalizedPath(request);
      if (!_requiresAuth(request.method, path)) {
        return inner(request);
      }

      final token = bearerToken(request);
      if (token == null) {
        return jsonError('Unauthorized', status: 401);
      }

      final row = await store.findSessionByTokenHash(sha256Hex(token));
      if (row == null) {
        return _authFailure('session_revoked');
      }
      if (!row.userActive) {
        if (row.sessionActive) {
          await store.endSession(row.sessionId, 'disabled');
        }
        return _authFailure('user_disabled');
      }
      if (!row.sessionActive) {
        if (row.logoutReason == 'expired') {
          return _authFailure('session_expired');
        }
        return _authFailure('session_revoked');
      }
      if (row.expired) {
        await store.endSession(row.sessionId, 'expired');
        return _authFailure('session_expired');
      }

      await store.touchLastActivity(row.sessionId);
      final principal = AuthPrincipal(
        userId: row.userId,
        username: row.username,
        name: row.name,
        role: row.role,
        sessionId: row.sessionId,
      );
      return inner(
        request.change(context: {authPrincipalContextKey: principal}),
      );
    };
  };
}

String? bearerToken(Request request) {
  final header = request.headers['authorization'];
  if (header == null) return null;
  final match = RegExp(r'^Bearer\s+(\S+)\s*$', caseSensitive: false).firstMatch(header.trim());
  if (match == null) return null;
  final token = match.group(1)!.trim();
  if (token.isEmpty) return null;
  return token;
}

bool _requiresAuth(String method, String path) {
  if (method.toUpperCase() == 'OPTIONS') return false;
  if (method.toUpperCase() == 'GET' && path == '/health') return false;
  if (method.toUpperCase() == 'POST' && path == '/api/auth/login') return false;
  return path.startsWith('/api');
}

String _normalizedPath(Request request) {
  var path = request.requestedUri.path;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

Response _authFailure(String code) {
  switch (code) {
    case 'session_expired':
      return jsonError(
        'This session expired after 12 hours of inactivity. Sign in again.',
        status: 401,
        code: code,
      );
    case 'user_disabled':
      return jsonError(
        'This account is disabled. Contact an administrator.',
        status: 401,
        code: code,
      );
    default:
      return jsonError(
        'This session has ended. Sign in again.',
        status: 401,
        code: 'session_revoked',
      );
  }
}
