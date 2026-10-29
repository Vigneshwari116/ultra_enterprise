/// In-memory login failures. Five failures in ten minutes for a username or
/// for an IP blocks the next attempt. An empty IP is not a shared bucket.
class LoginRateLimiter {
  LoginRateLimiter({
    this.maxAttempts = 5,
    this.window = const Duration(minutes: 10),
  });

  final int maxAttempts;
  final Duration window;
  final Map<String, List<DateTime>> _hits = {};

  bool isBlocked({
    required String username,
    required String ip,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    if (_count(_userKey(username), clock) >= maxAttempts) return true;
    final ipKey = _ipKey(ip);
    if (ipKey != null && _count(ipKey, clock) >= maxAttempts) return true;
    return false;
  }

  void recordFailure({
    required String username,
    required String ip,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    _add(_userKey(username), clock);
    final ipKey = _ipKey(ip);
    if (ipKey != null) _add(ipKey, clock);
  }

  void reset() => _hits.clear();

  String _userKey(String username) => 'u:${username.trim().toLowerCase()}';

  String? _ipKey(String ip) {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) return null;
    return 'ip:$trimmed';
  }

  int _count(String key, DateTime now) {
    final list = _hits[key];
    if (list == null) return 0;
    list.removeWhere((t) => now.difference(t) >= window);
    if (list.isEmpty) _hits.remove(key);
    return list.length;
  }

  void _add(String key, DateTime now) {
    final list = _hits.putIfAbsent(key, () => <DateTime>[]);
    list.removeWhere((t) => now.difference(t) >= window);
    list.add(now);
  }
}

final LoginRateLimiter loginRateLimiter = LoginRateLimiter();
