import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/ultra_repository.dart';
import '../utils/api_errors.dart';
import '../widgets/enterprise_widgets.dart';
import '../widgets/excel_grid.dart';

const _boxedBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(6)),
  borderSide: BorderSide(color: Color(0xFFB8BEC8)),
);

const _boxedFocusBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(6)),
  borderSide: BorderSide(color: Color(0xFF14B8A6), width: 1.6),
);

/// Shared boxed field used by the add-user and edit-user dialogs.
/// Labels sit above the box so they never overlap the value.
InputDecoration _boxedUserField({String? helperText}) {
  return const InputDecoration(
    filled: true,
    fillColor: Colors.white,
    isDense: false,
    border: _boxedBorder,
    enabledBorder: _boxedBorder,
    focusedBorder: _boxedFocusBorder,
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  ).copyWith(
    helperText: helperText,
    helperMaxLines: 2,
  );
}

class UsersSessionsScreen extends StatefulWidget {
  const UsersSessionsScreen({super.key});

  @override
  State<UsersSessionsScreen> createState() => _UsersSessionsScreenState();
}

class _UsersSessionsScreenState extends State<UsersSessionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Timer? _refresh;
  bool _loading = false;
  String? _error;
  int _onlineUsers = 0;
  List<Map<String, dynamic>> _onlineSessions = [];
  List<Map<String, dynamic>> _historySessions = [];
  List<Map<String, dynamic>> _users = [];
  DateTime? _dateFrom;
  DateTime? _dateTo;

  static final _stamp = DateFormat('dd MMM yyyy, HH:mm');
  static final _day = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      _armRefresh();
      _load();
    });
    _armRefresh();
    _load();
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  void _armRefresh() {
    _refresh?.cancel();
    _refresh = null;
    if (_tabs.index != 0) return;
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_tabs.index == 2) {
        final body = await UltraRepository.instance.adminUsers();
        if (!mounted) return;
        setState(() {
          _onlineUsers = _asInt(body['online_user_count']);
          _users = _maps(body['users']);
          _loading = false;
        });
        return;
      }
      final status = _tabs.index == 0 ? 'online' : 'history';
      final body = await UltraRepository.instance.adminSessions(
        status: status,
        dateFrom: status == 'history' && _dateFrom != null
            ? _day.format(_dateFrom!)
            : null,
        dateTo: status == 'history' && _dateTo != null
            ? _day.format(_dateTo!)
            : null,
      );
      if (!mounted) return;
      setState(() {
        _onlineUsers = _asInt(body['online_user_count']);
        final rows = _maps(body['sessions']);
        if (status == 'online') {
          _onlineSessions = rows;
        } else {
          _historySessions = rows;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final message = readableApiError(error);
      setState(() {
        _loading = false;
        _error = message;
      });
      showReadableErrorSnackBar(context, error);
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _dateFrom : _dateTo) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
    await _load();
  }

  Future<void> _logoutDevice(String sessionId) async {
    try {
      await UltraRepository.instance.adminLogoutSession(sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device logged out.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      showReadableErrorSnackBar(context, error);
    }
  }

  Future<void> _logoutAll(int userId, String label) async {
    final ok = await _confirm('Log out every device for $label?');
    if (!ok) return;
    try {
      await UltraRepository.instance.adminLogoutAll(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All sessions for that user were ended.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      showReadableErrorSnackBar(context, error);
    }
  }

  Future<void> _addUser() async {
    final username = TextEditingController();
    final name = TextEditingController();
    final password = TextEditingController();
    var role = 'user';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add user'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                    'Username',
                    TextField(
                        controller: username, decoration: _boxedUserField())),
                const SizedBox(height: 16),
                _dialogField('Name',
                    TextField(controller: name, decoration: _boxedUserField())),
                const SizedBox(height: 16),
                _dialogField(
                  'Password',
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: _boxedUserField(),
                  ),
                ),
                const SizedBox(height: 16),
                _dialogField(
                  'Role',
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    isExpanded: true,
                    isDense: false,
                    decoration: _boxedUserField(),
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text('user')),
                      DropdownMenuItem(
                          value: 'superuser', child: Text('superuser')),
                    ],
                    onChanged: (value) =>
                        setLocal(() => role = value ?? 'user'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    final usernameText = username.text.trim();
    final nameText = name.text.trim();
    final passwordText = password.text;
    username.dispose();
    name.dispose();
    password.dispose();
    if (saved != true) return;
    try {
      await UltraRepository.instance.adminCreateUser(
        username: usernameText,
        name: nameText,
        password: passwordText,
        role: role,
      );
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      showReadableErrorSnackBar(context, error);
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final name = TextEditingController(text: '${user['name'] ?? ''}');
    final password = TextEditingController();
    var role = '${user['role'] ?? 'user'}';
    if (role.isEmpty) role = 'user';
    final roleChoices = <String>[
      'user',
      'superuser',
      if (role != 'user' && role != 'superuser' && role.isNotEmpty) role,
    ];
    var active = user['is_active'] == true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Edit ${user['username']}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField('Name',
                    TextField(controller: name, decoration: _boxedUserField())),
                const SizedBox(height: 16),
                _dialogField(
                  'Role',
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    isExpanded: true,
                    isDense: false,
                    decoration: _boxedUserField(),
                    items: [
                      for (final choice in roleChoices)
                        DropdownMenuItem(value: choice, child: Text(choice)),
                    ],
                    onChanged: (value) => setLocal(() => role = value ?? role),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: active,
                  onChanged: (value) => setLocal(() => active = value),
                ),
                const SizedBox(height: 16),
                _dialogField(
                  'Reset password',
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: _boxedUserField(
                      helperText: 'Leave blank to keep the current password',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    final nameText = name.text.trim();
    final passwordText = password.text;
    name.dispose();
    password.dispose();
    if (saved != true) return;
    try {
      await UltraRepository.instance.adminUpdateUser(
        _asInt(user['id']),
        name: nameText,
        role: role,
        isActive: active,
        password: passwordText,
      );
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      showReadableErrorSnackBar(context, error);
    }
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out')),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: pageBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Users & Sessions',
                    style: TextStyle(
                        color: navy, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  'Users online now: $_onlineUsers',
                  style:
                      const TextStyle(color: teal, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, color: navy),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            labelColor: navy,
            tabs: const [
              Tab(text: 'Online now'),
              Tab(text: 'Login history'),
              Tab(text: 'Users'),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(_error!,
                  style:
                      const TextStyle(color: red, fontWeight: FontWeight.w700)),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                Column(
                  children: [
                    Expanded(child: _sessionTable(online: true)),
                  ],
                ),
                _history(),
                _userTable(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _history() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => _pickDate(from: true),
                child: Text(_dateFrom == null
                    ? 'From date'
                    : 'From ${_day.format(_dateFrom!)}'),
              ),
              OutlinedButton(
                onPressed: () => _pickDate(from: false),
                child: Text(_dateTo == null
                    ? 'To date'
                    : 'To ${_day.format(_dateTo!)}'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _dateFrom = null;
                    _dateTo = null;
                  });
                  _load();
                },
                child: const Text('Clear dates'),
              ),
            ],
          ),
        ),
        Expanded(child: _sessionTable(online: false)),
      ],
    );
  }

  Widget _sessionTable({required bool online}) {
    final rows = online ? _onlineSessions : _historySessions;
    if (rows.isEmpty && !_loading) {
      return const Center(child: Text('No sessions.'));
    }
    final headers = online
        ? const [
            'User',
            'Device',
            'IP',
            'Login time',
            'Last active',
            'Duration',
            'Logout'
          ]
        : const [
            'User',
            'Device',
            'IP',
            'Login time',
            'Logout time',
            'Duration',
            'Reason'
          ];
    final flex = online
        ? const [1.9, 1.4, 1.2, 1.6, 1.6, 1.0, 1.55]
        : const [2.0, 1.5, 1.3, 1.7, 1.7, 1.1, 1.4];
    return ExcelGrid(
      headers: headers,
      flex: flex,
      rows: [
        for (final row in rows)
          [
            _cellText(_userLabel(row)),
            _cellText('${row['device_name'] ?? ''}'),
            _cellText('${row['ip_address'] ?? ''}'),
            _cellText(_when(row['login_at'])),
            _cellText(
                online ? _when(row['last_activity']) : _when(row['logout_at'])),
            _cellText(_duration(row['duration_seconds'])),
            if (online)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: red,
                    backgroundColor: const Color(0xFFFFF1F1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => _logoutDevice('${row['id']}'),
                  child: const Text('Logout'),
                ),
              )
            else
              _cellText('${row['logout_reason'] ?? ''}'),
          ],
      ],
    );
  }

  Widget _userTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: ElevatedButton.icon(
              onPressed: _addUser,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add user'),
            ),
          ),
        ),
        Expanded(
          child: ExcelGrid(
            headers: const ['Username', 'Name', 'Role', 'Active', 'Actions'],
            flex: const [1.4, 1.6, 1.1, 0.8, 1.7],
            rows: [
              for (final user in _users)
                [
                  _cellText('${user['username'] ?? ''}'),
                  _cellText('${user['name'] ?? ''}'),
                  _cellText('${user['role'] ?? ''}'),
                  _cellText(user['is_active'] == true ? 'Yes' : 'No'),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      _smallAction('Edit', () => _editUser(user)),
                      _smallAction(
                        'Logout all',
                        () => _logoutAll(
                          _asInt(user['id']),
                          '${user['username'] ?? 'user'}',
                        ),
                      ),
                    ],
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _dialogField(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        field,
      ],
    );
  }

  Widget _cellText(String value) {
    final wrapped = value.replaceAllMapped(
      RegExp(r'\S{16,}'),
      (match) => match.group(0)!.split('').join('\u200B'),
    );
    return Text(wrapped, softWrap: true);
  }

  Widget _smallAction(String label, VoidCallback onPressed) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: navy,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  String _userLabel(Map<String, dynamic> row) {
    final name = '${row['name'] ?? ''}'.trim();
    final username = '${row['username'] ?? ''}'.trim();
    if (name.isEmpty) return username;
    if (username.isEmpty) return name;
    return '$name ($username)';
  }

  String _when(dynamic value) {
    if (value == null || '$value'.isEmpty) return '';
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return '$value';
    return _stamp.format(parsed.toLocal());
  }

  String _duration(dynamic value) {
    final seconds = _asInt(value);
    final safe = seconds < 0 ? 0 : seconds;
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    final secs = safe % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${secs}s';
    return '${secs}s';
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return [];
    return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
