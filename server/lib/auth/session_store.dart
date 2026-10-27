import 'package:postgres/postgres.dart';

import 'db_values.dart';

class SessionAuthRow {
  SessionAuthRow({
    required this.sessionId,
    required this.userId,
    required this.sessionActive,
    required this.logoutReason,
    required this.expired,
    required this.userActive,
    required this.username,
    required this.name,
    required this.role,
  });

  final String sessionId;
  final int userId;
  final bool sessionActive;
  final String? logoutReason;
  final bool expired;
  final bool userActive;
  final String username;
  final String name;
  final String role;
}

class AppUserRow {
  AppUserRow({
    required this.id,
    required this.username,
    required this.name,
    required this.passwordHash,
    required this.role,
    required this.isActive,
  });

  final int id;
  final String username;
  final String name;
  final String passwordHash;
  final String role;
  final bool isActive;
}

class SessionStore {
  SessionStore(this.conn);

  final Connection conn;

  Future<AppUserRow?> findUserByUsername(String username) async {
    final rows = await conn.execute(
      Sql.named('''
        SELECT id, username, name, password_hash, role, is_active
        FROM public.app_users
        WHERE LOWER(username) = LOWER(@username)
      '''),
      parameters: {'username': username},
    );
    if (rows.isEmpty) return null;
    return _userFrom(rows.first.toColumnMap());
  }

  Future<AppUserRow?> findUserById(int id) async {
    final rows = await conn.execute(
      Sql.named('''
        SELECT id, username, name, password_hash, role, is_active
        FROM public.app_users
        WHERE id = @id
      '''),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return null;
    return _userFrom(rows.first.toColumnMap());
  }

  Future<int> insertUser({
    required String username,
    required String name,
    required String passwordHash,
    required String role,
    bool isActive = true,
  }) async {
    final rows = await conn.execute(
      Sql.named('''
        INSERT INTO public.app_users (username, name, password_hash, role, is_active)
        VALUES (@username, @name, @password_hash, @role, @is_active)
        RETURNING id
      '''),
      parameters: {
        'username': username,
        'name': name,
        'password_hash': passwordHash,
        'role': role,
        'is_active': isActive,
      },
    );
    return asInt(rows.first.first);
  }

  Future<int> countUsers() async {
    final rows = await conn.execute('SELECT COUNT(*) FROM public.app_users');
    return asInt(rows.first.first);
  }

  Future<void> createSession({
    required String id,
    required int userId,
    required String tokenHash,
    String? deviceName,
    String? ipAddress,
  }) async {
    await conn.execute(
      Sql.named('''
        INSERT INTO public.app_sessions (
          id, user_id, token_hash, device_name, ip_address
        ) VALUES (
          CAST(@id AS uuid), @user_id, @token_hash, @device_name, @ip_address
        )
      '''),
      parameters: {
        'id': id,
        'user_id': userId,
        'token_hash': tokenHash,
        'device_name': deviceName,
        'ip_address': ipAddress,
      },
    );
  }

  Future<SessionAuthRow?> findSessionByTokenHash(String tokenHash) async {
    final rows = await conn.execute(
      Sql.named('''
        SELECT
          s.id::text AS session_id,
          s.user_id,
          s.is_active AS session_active,
          s.logout_reason,
          (s.last_activity < NOW() - INTERVAL '12 hours') AS expired,
          u.is_active AS user_active,
          u.username,
          u.name,
          u.role
        FROM public.app_sessions s
        JOIN public.app_users u ON u.id = s.user_id
        WHERE s.token_hash = @token_hash
      '''),
      parameters: {'token_hash': tokenHash},
    );
    if (rows.isEmpty) return null;
    final map = rows.first.toColumnMap();
    final reason = map['logout_reason'];
    return SessionAuthRow(
      sessionId: '${map['session_id']}',
      userId: asInt(map['user_id']),
      sessionActive: asBool(map['session_active']),
      logoutReason: reason == null ? null : '$reason',
      expired: asBool(map['expired']),
      userActive: asBool(map['user_active']),
      username: '${map['username']}',
      name: '${map['name']}',
      role: '${map['role']}',
    );
  }

  Future<void> touchLastActivity(String sessionId) async {
    await conn.execute(
      Sql.named('''
        UPDATE public.app_sessions
        SET last_activity = NOW()
        WHERE id = CAST(@id AS uuid)
          AND is_active = TRUE
          AND last_activity <= NOW() - INTERVAL '1 minute'
      '''),
      parameters: {'id': sessionId},
    );
  }

  Future<void> endSession(String sessionId, String reason) async {
    await conn.execute(
      Sql.named('''
        UPDATE public.app_sessions
        SET is_active = FALSE,
            logout_at = COALESCE(logout_at, NOW()),
            logout_reason = COALESCE(logout_reason, @reason)
        WHERE id = CAST(@id AS uuid)
          AND is_active = TRUE
      '''),
      parameters: {'id': sessionId, 'reason': reason},
    );
  }

  Future<int> endSessionsForUser(int userId, String reason) async {
    final rows = await conn.execute(
      Sql.named('''
        UPDATE public.app_sessions
        SET is_active = FALSE,
            logout_at = COALESCE(logout_at, NOW()),
            logout_reason = @reason
        WHERE user_id = @user_id
          AND is_active = TRUE
        RETURNING id
      '''),
      parameters: {'user_id': userId, 'reason': reason},
    );
    return rows.length;
  }

  Future<bool> sessionExists(String sessionId) async {
    final rows = await conn.execute(
      Sql.named('''
        SELECT 1 FROM public.app_sessions WHERE id = CAST(@id AS uuid)
      '''),
      parameters: {'id': sessionId},
    );
    return rows.isNotEmpty;
  }

  Future<int> onlineUserCount() async {
    final rows = await conn.execute('''
      SELECT COUNT(DISTINCT user_id)
      FROM public.app_sessions
      WHERE is_active = TRUE
        AND last_activity >= NOW() - INTERVAL '5 minutes'
    ''');
    return asInt(rows.first.first);
  }

  Future<List<Map<String, dynamic>>> listSessions({
    required bool onlineOnly,
    String? dateFrom,
    String? dateTo,
  }) async {
    final rows = await conn.execute(
      Sql.named('''
        SELECT
          s.id::text AS id,
          s.user_id,
          u.username,
          u.name,
          s.device_name,
          s.ip_address,
          s.login_at,
          s.last_activity,
          s.logout_at,
          s.logout_reason,
          s.is_active,
          FLOOR(EXTRACT(EPOCH FROM (COALESCE(s.logout_at, NOW()) - s.login_at)))::bigint
            AS duration_seconds
        FROM public.app_sessions s
        JOIN public.app_users u ON u.id = s.user_id
        WHERE (
          @online_only = FALSE
          OR (
            s.is_active = TRUE
            AND s.last_activity >= NOW() - INTERVAL '5 minutes'
          )
        )
        AND (
          @online_only = TRUE
          OR @date_from::text IS NULL
          OR s.login_at::date >= CAST(@date_from AS date)
        )
        AND (
          @online_only = TRUE
          OR @date_to::text IS NULL
          OR s.login_at::date <= CAST(@date_to AS date)
        )
        ORDER BY s.login_at DESC
      '''),
      parameters: {
        'online_only': onlineOnly,
        'date_from': dateFrom,
        'date_to': dateTo,
      },
    );
    return rows.map((row) => row.toColumnMap()).toList();
  }

  Future<List<Map<String, dynamic>>> listUsers() async {
    final rows = await conn.execute('''
      SELECT id, username, name, role, is_active, created_at
      FROM public.app_users
      ORDER BY username ASC, id ASC
    ''');
    return rows.map((row) => row.toColumnMap()).toList();
  }

  /// Returns `not_found`, `last_superuser`, or null on success.
  /// When the user is disabled, every active session is ended with reason `disabled`.
  Future<String?> updateUser({
    required int id,
    String? name,
    String? role,
    bool? isActive,
    String? passwordHash,
  }) async {
    return conn.runTx((tx) async {
      await tx.execute(
        "SELECT id FROM public.app_users WHERE role = 'superuser' AND is_active FOR UPDATE",
      );
      final rows = await tx.execute(
        Sql.named('''
          SELECT id, role, is_active
          FROM public.app_users
          WHERE id = @id
          FOR UPDATE
        '''),
        parameters: {'id': id},
      );
      if (rows.isEmpty) return 'not_found';
      final current = rows.first.toColumnMap();
      final currentRole = '${current['role']}';
      final currentActive = asBool(current['is_active']);
      final nextRole = role ?? currentRole;
      final nextActive = isActive ?? currentActive;
      final wasActiveSuperuser = currentRole == 'superuser' && currentActive;
      final staysActiveSuperuser = nextRole == 'superuser' && nextActive;
      if (wasActiveSuperuser && !staysActiveSuperuser) {
        final others = await tx.execute(
          Sql.named('''
            SELECT COUNT(*)
            FROM public.app_users
            WHERE role = 'superuser'
              AND is_active = TRUE
              AND id <> @id
          '''),
          parameters: {'id': id},
        );
        if (asInt(others.first.first) == 0) return 'last_superuser';
      }

      await tx.execute(
        Sql.named('''
          UPDATE public.app_users
          SET name = COALESCE(@name, name),
              role = COALESCE(@role, role),
              is_active = COALESCE(@is_active, is_active),
              password_hash = COALESCE(@password_hash, password_hash)
          WHERE id = @id
        '''),
        parameters: {
          'id': id,
          'name': name,
          'role': role,
          'is_active': isActive,
          'password_hash': passwordHash,
        },
      );

      if (currentActive && !nextActive) {
        await tx.execute(
          Sql.named('''
            UPDATE public.app_sessions
            SET is_active = FALSE,
                logout_at = COALESCE(logout_at, NOW()),
                logout_reason = 'disabled'
            WHERE user_id = @id
              AND is_active = TRUE
          '''),
          parameters: {'id': id},
        );
      }
      return null;
    });
  }

  AppUserRow _userFrom(Map<String, dynamic> map) {
    return AppUserRow(
      id: asInt(map['id']),
      username: '${map['username']}',
      name: '${map['name']}',
      passwordHash: '${map['password_hash']}',
      role: '${map['role']}',
      isActive: asBool(map['is_active']),
    );
  }
}
