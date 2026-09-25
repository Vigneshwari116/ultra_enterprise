/// Runtime configuration for Ultra Enterprise data layer.
class UltraConfig {
  UltraConfig._();

  /// When true, uses on-device SQLite (full module coverage). When false, uses the
  /// Ultra REST API — note the live API currently exposes only a subset of routes.
  static const bool persistLocally = true;

  /// Deployed Ultra API origin (no trailing slash). Override for your VPS.
  static const String apiBaseUrl = String.fromEnvironment(
    'ULTRA_API_URL',
    defaultValue: 'https://api.ultra.winagrum.tech',
  );
}
