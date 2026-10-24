import 'dart:io';

/// Candidate absolute paths for [relativePath] when `dart test` runs from repo root or `server/`.
List<String> buildServerRelativePathCandidates(String cwd, String relativePath) {
  return <String>[
    '$cwd/$relativePath',
    if (!cwd.endsWith('server')) '$cwd/server/$relativePath',
  ];
}

bool serverRelativePathExists(String absolutePath) =>
    FileSystemEntity.typeSync(absolutePath) != FileSystemEntityType.notFound;

/// Resolve a repo-relative path when `dart test` runs from `server/` or repo root.
String resolveServerRelativePath(String relativePath) {
  final tried = <String>[];
  final cwd = Directory.current.path;

  for (final path in buildServerRelativePathCandidates(cwd, relativePath)) {
    tried.add(path);
    if (serverRelativePathExists(path)) return path;
  }

  throw StateError(
    'Could not find $relativePath (cwd=$cwd). Tried:\n${tried.map((p) => '  - $p').join('\n')}',
  );
}

String vpsFixturesDir() => resolveServerRelativePath('test/fixtures');

String vpsMigrationPath() =>
    resolveServerRelativePath('schema/migrations/001_accounting.sql');

List<String> vpsMigrationPaths() => [
      vpsMigrationPath(),
      resolveServerRelativePath('schema/migrations/002_sales_bill_type.sql'),
    ];
