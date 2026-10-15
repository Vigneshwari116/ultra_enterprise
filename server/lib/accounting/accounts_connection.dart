import 'dart:io' show Platform;

import 'package:postgres/postgres.dart';

/// Primary app database (vouchers, masters).
Connection openPrimaryConnection() {
  final url = Platform.environment['DATABASE_URL'];
  if (url == null || url.isEmpty) {
    throw StateError('DATABASE_URL is required');
  }
  return Connection.openFromUrl(url);
}

Future<Connection> openPrimaryConnectionAsync() => openPrimaryConnection();

/// Accounting tables (ledgers, journal_entries). Defaults to primary DB.
Future<Connection> openAccountsConnection() async {
  final dedicated = Platform.environment['ACCOUNTS_DATABASE_URL'];
  final url = (dedicated != null && dedicated.isNotEmpty)
      ? dedicated
      : Platform.environment['DATABASE_URL'];
  if (url == null || url.isEmpty) {
    throw StateError('DATABASE_URL or ACCOUNTS_DATABASE_URL is required');
  }
  return Connection.openFromUrl(url);
}

bool accountsUsesSeparateDatabase() {
  final dedicated = Platform.environment['ACCOUNTS_DATABASE_URL'];
  final primary = Platform.environment['DATABASE_URL'] ?? '';
  return dedicated != null &&
      dedicated.isNotEmpty &&
      dedicated != primary;
}
