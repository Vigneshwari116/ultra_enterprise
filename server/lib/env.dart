import 'dart:io' show Platform;

class Env {
  static String get databaseUrl {
    final fromEnv = Platform.environment['DATABASE_URL'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    throw StateError('DATABASE_URL is required');
  }

  static int get port => int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
}
