/// Runtime configuration for Ultra Enterprise data layer.
class UltraConfig {
  UltraConfig._();

  /// When true, uses on-device SQLite (full module coverage). When false, uses the
  /// Ultra REST API as the primary data source.
  static const bool persistLocally = false;

  static const String _defaultApiOrigin = 'https://api.ultra.winagrum.tech';

  /// Optional runtime override (e.g. settings screen); takes precedence over compile-time defines.
  static String? apiBaseUrlOverride;

  /// REST API origin (no trailing slash).
  ///
  /// Compile-time: `--dart-define=API_BASE_URL=http://127.0.0.1:3004`
  /// or legacy `--dart-define=ULTRA_API_URL=...`
  static String get apiBaseUrl {
    final override = apiBaseUrlOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return _stripTrailingSlash(override);
    }
    const fromApiBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromApiBase.isNotEmpty) {
      return _stripTrailingSlash(fromApiBase);
    }
    const fromUltra = String.fromEnvironment('ULTRA_API_URL', defaultValue: '');
    if (fromUltra.isNotEmpty) {
      return _stripTrailingSlash(fromUltra);
    }
    return _defaultApiOrigin;
  }

  static String _stripTrailingSlash(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}
