import 'dart:io';

import 'package:test/test.dart';

import 'test_fixture_paths.dart';

void main() {
  test('buildServerRelativePathCandidates dedupes when cwd is server/', () {
    expect(
      buildServerRelativePathCandidates('/workspace/server', 'test/fixtures'),
      ['/workspace/server/test/fixtures'],
    );
  });

  test('buildServerRelativePathCandidates includes server/ prefix from repo root', () {
    expect(
      buildServerRelativePathCandidates('/workspace', 'test/fixtures'),
      ['/workspace/test/fixtures', '/workspace/server/test/fixtures'],
    );
  });

  test('serverRelativePathExists finds files and directories', () {
    final dir = Directory.systemTemp.createTempSync('fixture_paths_test_');
    final sub = Directory('${dir.path}/nested');
    sub.createSync();
    final file = File('${dir.path}/file.txt');
    file.writeAsStringSync('x');

    expect(serverRelativePathExists(dir.path), isTrue);
    expect(serverRelativePathExists(sub.path), isTrue);
    expect(serverRelativePathExists(file.path), isTrue);
    expect(serverRelativePathExists('${dir.path}/missing'), isFalse);

    dir.deleteSync(recursive: true);
  });

  test('resolveServerRelativePath finds accounting migration', () {
    final path = resolveServerRelativePath('schema/migrations/001_accounting.sql');
    expect(serverRelativePathExists(path), isTrue);
    expect(path.endsWith('001_accounting.sql'), isTrue);
  });
}
