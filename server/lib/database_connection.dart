import 'package:postgres/postgres.dart';

/// Opens PostgreSQL using [DATABASE_URL], honouring `sslmode` query parameter.
///
/// postgres 3.5.x supports only [SslMode.disable], [SslMode.require], and
/// [SslMode.verifyFull]. Mapping: verify-ca → verifyFull; prefer/default → require.
Future<Connection> openDatabaseFromUrl(String url) async {
  final uri = Uri.parse(url);
  final sslMode = _sslModeFromQuery(uri.queryParameters['sslmode']);

  final host = uri.host.isEmpty ? 'localhost' : uri.host;
  final port = uri.hasPort ? uri.port : 5432;
  final database = uri.pathSegments.isEmpty
      ? ''
      : uri.pathSegments.first.replaceFirst('/', '');
  final username = uri.userInfo.isEmpty ? null : Uri.decodeComponent(uri.userInfo.split(':').first);
  final password = uri.userInfo.contains(':')
      ? Uri.decodeComponent(uri.userInfo.split(':').skip(1).join(':'))
      : null;

  return Connection.open(
    Endpoint(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    ),
    settings: ConnectionSettings(sslMode: sslMode),
  );
}

SslMode _sslModeFromQuery(String? sslmode) {
  switch (sslmode?.toLowerCase()) {
    case 'disable':
      return SslMode.disable;
    case 'require':
      return SslMode.require;
    case 'verify-full':
      return SslMode.verifyFull;
    case 'verify-ca':
      return SslMode.verifyFull;
    case 'prefer':
    default:
      return SslMode.require;
  }
}
