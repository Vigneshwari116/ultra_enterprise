import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/ultra_repository.dart';
import '../utils/api_errors.dart';
import '../widgets/enterprise_widgets.dart';

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
        dateFrom: status == 'history' && _dateFrom != null ? _day.format(_dateFrom!) : null,
        dateTo: status == 'history' && _dateTo != null ? _day.format(_dateTo!) : null,
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
                TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('user')),
                    DropdownMenuItem(value: 'admin', child: Text('admin')),
                    DropdownMenuItem(value: 'superuser', child: Text('superuser')),
                  ],
                  onChanged: (value) => setLocal(() => role = value ?? 'user'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
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
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('user')),
                    DropdownMenuItem(value: 'admin', child: Text('admin')),
                    DropdownMenuItem(value: 'superuser', child: Text('superuser')),
                  ],
                  onChanged: (value) => setLocal(() => role = value ?? role),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: active,
                  onChanged: (value) => setLocal(() => active = value),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Reset password',
                    helperText: 'Leave blank to keep the current password',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
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
                    style: TextStyle(color: navy, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  'Users online now: $_onlineUsers',
                  style: const TextStyle(color: teal, fontWeight: FontWeight.w800),
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
              child: Text(_error!, style: const TextStyle(color: red, fontWeight: FontWeight.w700)),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _sessionTable(online: true),
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
                child: Text(_dateFrom == null ? 'From date' : 'From ${_day.format(_dateFrom!)}'),
              ),
              OutlinedButton(
                onPressed: () => _pickDate(from: false),
                child: Text(_dateTo == null ? 'To date' : 'To ${_day.format(_dateTo!)}'),
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
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: [
              const DataColumn(label: Text('User')),
              const DataColumn(label: Text('Device')),
              const DataColumn(label: Text('IP')),
              const DataColumn(label: Text('Login time')),
              if (online) const DataColumn(label: Text('Last active')),
              if (!online) const DataColumn(label: Text('Logout time')),
              const DataColumn(label: Text('Duration')),
              if (!online) const DataColumn(label: Text('Reason')),
              if (online) const DataColumn(label: Text('')),
            ],
            rows: [
              for (final row in rows)
                DataRow(cells: [
                  DataCell(Text(_userLabel(row))),
                  DataCell(Text('${row['device_name'] ?? ''}')),
                  DataCell(Text('${row['ip_address'] ?? ''}')),
                  DataCell(Text(_when(row['login_at']))),
                  if (online) DataCell(Text(_when(row['last_activity']))),
                  if (!online) DataCell(Text(_when(row['logout_at']))),
                  DataCell(Text(_duration(row['duration_seconds']))),
                  if (!online) DataCell(Text('${row['logout_reason'] ?? ''}')),
                  if (online)
                    DataCell(TextButton(
                      onPressed: () => _logoutDevice('${row['id']}'),
                      child: const Text('Logout device'),
                    )),
                ]),
            ],
          ),
        ),
      ),
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
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Username')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Active')),
                    DataColumn(label: Text('')),
                  ],
                  rows: [
                    for (final user in _users)
                      DataRow(cells: [
                        DataCell(Text('${user['username'] ?? ''}')),
                        DataCell(Text('${user['name'] ?? ''}')),
                        DataCell(Text('${user['role'] ?? ''}')),
                        DataCell(Text(user['is_active'] == true ? 'Yes' : 'No')),
                        DataCell(Wrap(
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: () => _editUser(user),
                              child: const Text('Edit'),
                            ),
                            TextButton(
                              onPressed: () => _logoutAll(
                                _asInt(user['id']),
                                '${user['username'] ?? 'user'}',
                              ),
                              child: const Text('Logout all'),
                            ),
                          ],
                        )),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
