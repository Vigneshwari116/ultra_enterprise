import 'package:shelf/shelf.dart';

class AuthPrincipal {
  AuthPrincipal({
    required this.userId,
    required this.username,
    required this.name,
    required this.role,
    required this.sessionId,
  });

  final int userId;
  final String username;
  final String name;
  final String role;
  final String sessionId;

  bool get isAdmin => role == 'superuser' || role == 'admin';

  Map<String, Object?> toJson() => {
        'id': userId,
        'username': username,
        'name': name,
        'role': role,
      };
}

const String authPrincipalContextKey = 'ultra.auth.principal';

AuthPrincipal? principalOf(Request request) {
  final value = request.context[authPrincipalContextKey];
  if (value is AuthPrincipal) return value;
  return null;
}

bool isAdminRole(String role) => role == 'superuser' || role == 'admin';

const Set<String> userRoles = {'superuser', 'admin', 'user'};
