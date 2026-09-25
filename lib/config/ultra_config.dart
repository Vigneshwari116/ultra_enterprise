/// Runtime configuration for Ultra Enterprise data layer.
class UltraConfig {
  UltraConfig._();

  /// When false, reads and writes go to the Ultra REST API (no SQLite persistence).
  static const bool persistLocally = false;

  /// Deployed Ultra API origin (no trailing slash). Override for your VPS.
  static const String apiBaseUrl = String.fromEnvironment(
    'ULTRA_API_URL',
    defaultValue: 'http://127.0.0.1:8081',
  );
}
