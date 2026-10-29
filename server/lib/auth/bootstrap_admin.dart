import 'dart:io';

import 'package:postgres/postgres.dart';

import 'password_hash.dart';
import 'session_store.dart';

/// When `app_users` is empty, create one superuser from the environment.
/// Missing variables or a missing table are logged. The process still starts.
Future<void> ensureInitialAdmin(Connection conn) async {
  final store = SessionStore(conn);
  final int count;
  try {
    count = await store.countUsers();
  } catch (error) {
    stderr.writeln(
      'ERROR: could not read app_users ($error). '
      'Apply schema/migrations/003_users_sessions.sql. No superuser was created.',
    );
    return;
  }
  if (count > 0) return;

  final username = (Platform.environment['INITIAL_ADMIN_USERNAME'] ?? '').trim();
  final password = Platform.environment['INITIAL_ADMIN_PASSWORD'] ?? '';
  if (username.isEmpty || password.isEmpty) {
    stderr.writeln(
      'ERROR: app_users is empty but INITIAL_ADMIN_USERNAME and INITIAL_ADMIN_PASSWORD '
      'are not both set. No superuser was created. Set both variables and restart the server.',
    );
    return;
  }
  if (passwordByteLength(password) > passwordMaxBytes) {
    stderr.writeln(
      'ERROR: INITIAL_ADMIN_PASSWORD is longer than $passwordMaxBytes bytes. '
      'No superuser was created.',
    );
    return;
  }

  try {
    await store.insertUser(
      username: username,
      name: username,
      passwordHash: hashPassword(password),
      role: 'superuser',
    );
    stdout.writeln('Created initial superuser "$username".');
  } catch (error) {
    stderr.writeln(
      'ERROR: failed to create the initial superuser "$username" (${error.runtimeType}). '
      'Apply schema/migrations/003_users_sessions.sql and restart.',
    );
  }
}
