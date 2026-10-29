import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:ultra_api_server/auth/login_rate_limiter.dart';

import 'auth_test_helper.dart';
import 'test_fixture_paths.dart';

void main() {
  test('rate limiter blocks a username after 5 failures inside 10 minutes', () {
    final limiter = LoginRateLimiter();
    final start = DateTime.utc(2026, 10, 27, 8);
    for (var i = 0; i < 5; i++) {
      expect(limiter.isBlocked(username: 'Ada', ip: '', now: start), isFalse);
      limiter.recordFailure(username: 'Ada', ip: '', now: start.add(Duration(seconds: i)));
    }
    expect(
      limiter.isBlocked(username: 'ada', ip: '', now: start.add(const Duration(minutes: 9))),
      isTrue,
    );
    expect(
      limiter.isBlocked(username: 'ada', ip: '', now: start.add(const Duration(minutes: 10, seconds: 1))),
      isFalse,
    );
  });

  test('rate limiter blocks an IP and does not share an empty IP bucket', () {
    final limiter = LoginRateLimiter();
    final now = DateTime.utc(2026, 10, 27, 9);
    for (var i = 0; i < 5; i++) {
      limiter.recordFailure(username: 'user-$i', ip: '203.0.113.9', now: now);
    }
    expect(limiter.isBlocked(username: 'someone-else', ip: '203.0.113.9', now: now), isTrue);
    expect(limiter.isBlocked(username: 'someone-else', ip: '', now: now), isFalse);
  });

  final testDbUrl = Platform.environment['TEST_DATABASE_URL'];

  group('auth and admin routes', () {
    if (testDbUrl == null || testDbUrl.isEmpty) {
      test('skipped without TEST_DATABASE_URL', () {}, skip: 'Set TEST_DATABASE_URL to a database ending in _test');
      return;
    }

    late Connection conn;
    late TestLogin admin;

    Future<void> runPsqlFile(String path) async {
      final result = await Process.run(
        'psql',
        [testDbUrl, '-v', 'ON_ERROR_STOP=1', '-q', '-f', path],
      );
      if (result.exitCode != 0) {
        throw StateError('psql failed for $path: ${result.stderr}\n${result.stdout}');
      }
    }

    setUpAll(() async {
      assertTestDatabaseUrl(testDbUrl);
      final which = await Process.run('which', ['psql']);
      if (which.exitCode != 0) {
        throw StateError('psql not found on PATH. Install postgresql-client to run auth_routes_test.');
      }
    });

    setUp(() async {
      loginRateLimiter.reset();
      final fixturesDir = vpsFixturesDir();
      await runPsqlFile('$fixturesDir/reset_test_schema.sql');
      await runPsqlFile('$fixturesDir/vps_ultra_enterprise_schema.sql');
      await runPsqlFile('$fixturesDir/vps_ultra_enterprise_seed.sql');
      for (final path in vpsMigrationPaths()) {
        await runPsqlFile(path);
      }
      conn = await openTestDatabase(testDbUrl);
      admin = await loginTestAdmin(conn);
    });

    tearDown(() async {
      await conn.close();
    });

    test('login succeeds and stores only the token hash', () async {
      final rows = await conn.execute(
        Sql.named('''
          SELECT token_hash
          FROM public.app_sessions
          WHERE id = CAST(@id AS uuid)
        '''),
        parameters: {'id': admin.sessionId},
      );
      final hash = '${rows.first.first}';
      expect(hash, hasLength(64));
      expect(hash, isNot(admin.token));
      expect(hash.contains(admin.token), isFalse);

      final me = await callApi(conn, 'GET', '/api/auth/me', token: admin.token);
      final body = jsonDecode(await me.readAsString()) as Map<String, dynamic>;
      expect(me.statusCode, 200);
      expect(body['session_id'], admin.sessionId);
      expect((body['user'] as Map)['username'], testAdminUsername);
      expect((body['user'] as Map)['role'], 'superuser');
      expect(body.containsKey('password'), isFalse);
      expect(body.containsKey('password_hash'), isFalse);
    });

    test('wrong password and disabled user return the same 401', () async {
      await insertTestUser(
        conn,
        username: 'pw_user',
        password: 'correct-pass',
        role: 'user',
      );
      await insertTestUser(
        conn,
        username: 'disabled_user',
        password: 'correct-pass',
        role: 'user',
        active: false,
      );

      final wrong = await callApi(conn, 'POST', '/api/auth/login', body: {
        'username': 'pw_user',
        'password': 'not-the-password',
        'device_name': 'test',
      });
      final wrongBody = jsonDecode(await wrong.readAsString()) as Map;
      final disabled = await callApi(conn, 'POST', '/api/auth/login', body: {
        'username': 'disabled_user',
        'password': 'correct-pass',
        'device_name': 'test',
      });
      final disabledBody = jsonDecode(await disabled.readAsString()) as Map;

      expect(wrong.statusCode, 401);
      expect(disabled.statusCode, 401);
      expect(wrongBody['error'], 'Invalid username or password');
      expect(disabledBody['error'], wrongBody['error']);
      expect(wrongBody['code'], isNull);
      expect(disabledBody['code'], isNull);
      expect('${wrongBody['error']}'.toLowerCase().contains('disabled'), isFalse);
    });

    test('customers require a token', () async {
      final missing = await callApi(conn, 'GET', '/api/customers');
      expect(missing.statusCode, 401);
      final authed = await callApi(conn, 'GET', '/api/customers', token: admin.token);
      expect(authed.statusCode, 200, reason: await authed.readAsString());
    });

    test('logout makes that token fail', () async {
      final out = await callApi(conn, 'POST', '/api/auth/logout', token: admin.token, body: {});
      expect(out.statusCode, 200);
      final again = await callApi(conn, 'GET', '/api/customers', token: admin.token);
      final body = jsonDecode(await again.readAsString()) as Map;
      expect(again.statusCode, 401);
      expect(body['code'], 'session_revoked');
    });

    test('admin logout of one device leaves the other session', () async {
      const username = 'device_user';
      const password = 'device-pass';
      final first = await loginTestUser(
        conn,
        username: username,
        password: password,
        deviceName: 'device-a',
      );
      final second = await loginExisting(
        conn,
        username: username,
        password: password,
        deviceName: 'device-b',
      );

      final kill = await callApi(
        conn,
        'POST',
        '/api/admin/sessions/${first.sessionId}/logout',
        token: admin.token,
        body: {},
      );
      expect(kill.statusCode, 200);

      final firstMe = await callApi(conn, 'GET', '/api/auth/me', token: first.token);
      expect(firstMe.statusCode, 401);
      final secondMe = await callApi(conn, 'GET', '/api/auth/me', token: second.token);
      expect(secondMe.statusCode, 200);
    });

    test('logout-all ends every session for that user', () async {
      const username = 'multi_user';
      const password = 'multi-pass';
      final first = await loginTestUser(
        conn,
        username: username,
        password: password,
        deviceName: 'device-a',
      );
      final second = await loginExisting(
        conn,
        username: username,
        password: password,
        deviceName: 'device-b',
      );
      final kill = await callApi(
        conn,
        'POST',
        '/api/admin/users/${first.userId}/logout-all',
        token: admin.token,
        body: {},
      );
      expect(kill.statusCode, 200);
      expect((await callApi(conn, 'GET', '/api/auth/me', token: first.token)).statusCode, 401);
      expect((await callApi(conn, 'GET', '/api/auth/me', token: second.token)).statusCode, 401);
    });

    test('a non-admin receives 403 on admin routes', () async {
      final user = await loginTestUser(
        conn,
        username: 'plain_user',
        password: 'plain-pass',
        role: 'user',
      );
      final users = await callApi(conn, 'GET', '/api/admin/users', token: user.token);
      expect(users.statusCode, 403);
      final sessions = await callApi(
        conn,
        'GET',
        '/api/admin/sessions?status=online',
        token: user.token,
      );
      expect(sessions.statusCode, 403);
    });

    test('last_activity is not written on every request', () async {
      Future<String> activity() async {
        final rows = await conn.execute(
          Sql.named('''
            SELECT last_activity::text AS ts
            FROM public.app_sessions
            WHERE id = CAST(@id AS uuid)
          '''),
          parameters: {'id': admin.sessionId},
        );
        return '${rows.first.toColumnMap()['ts']}';
      }

      final before = await activity();
      final me = await callApi(conn, 'GET', '/api/auth/me', token: admin.token);
      expect(me.statusCode, 200);
      await me.readAsString();
      expect(await activity(), before);

      await conn.execute(
        Sql.named('''
          UPDATE public.app_sessions
          SET last_activity = NOW() - INTERVAL '2 minutes'
          WHERE id = CAST(@id AS uuid)
        '''),
        parameters: {'id': admin.sessionId},
      );
      final stale = await activity();
      final again = await callApi(conn, 'GET', '/api/customers', token: admin.token);
      expect(again.statusCode, 200);
      await again.readAsString();
      expect(await activity(), isNot(stale));
    });

    test('the last active superuser cannot be disabled or demoted', () async {
      final disable = await callApi(
        conn,
        'PUT',
        '/api/admin/users/${admin.userId}',
        token: admin.token,
        body: {'is_active': false},
      );
      expect(disable.statusCode, 409, reason: await disable.readAsString());

      final demote = await callApi(
        conn,
        'PUT',
        '/api/admin/users/${admin.userId}',
        token: admin.token,
        body: {'role': 'user'},
      );
      expect(demote.statusCode, 409, reason: await demote.readAsString());

      final created = await callApi(
        conn,
        'POST',
        '/api/admin/users',
        token: admin.token,
        body: {
          'username': 'second_super',
          'name': 'Second Super',
          'password': 'second-pass',
          'role': 'superuser',
        },
      );
      expect(created.statusCode, 201, reason: await created.readAsString());

      final disableNow = await callApi(
        conn,
        'PUT',
        '/api/admin/users/${admin.userId}',
        token: admin.token,
        body: {'is_active': false},
      );
      expect(disableNow.statusCode, 200, reason: await disableNow.readAsString());

      final me = await callApi(conn, 'GET', '/api/auth/me', token: admin.token);
      final body = jsonDecode(await me.readAsString()) as Map;
      expect(me.statusCode, 401);
      expect(body['code'], 'user_disabled');
    });
  });
}
