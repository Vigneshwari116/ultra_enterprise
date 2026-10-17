import 'dart:io';

/// Resolve a repo-relative path when `dart test` runs from `server/` or repo root.
String resolveServerRelativePath(String relativePath) {
  final tried = <String>[];
  final cwd = Directory.current.path;

  final candidates = <String>[
    '$cwd/$relativePath',
    if (cwd.endsWith('server')) '$cwd/$relativePath' else '$cwd/server/$relativePath',
  ];

  for (final path in candidates) {
    tried.add(path);
    if (File(path).existsSync()) return path;
  }

  throw StateError(
    'Could not find $relativePath (cwd=$cwd). Tried:\n${tried.map((p) => '  - $p').join('\n')}',
  );
}

String vpsFixturesDir() => resolveServerRelativePath('test/fixtures');

String vpsMigrationPath() =>
    resolveServerRelativePath('schema/migrations/001_accounting.sql');
