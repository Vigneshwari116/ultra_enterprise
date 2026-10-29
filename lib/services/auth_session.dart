import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'device_name.dart';

/// In-memory token plus the same value in shared_preferences.
class AuthSession extends ChangeNotifier {
  AuthSession._();
  static final AuthSession instance = AuthSession._();

  static const prefsKey = 'auth_token';

  String? token;
  Map<String, dynamic>? user;
  bool ready = false;
  String? blockedMessage;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  bool get isAdmin {
    final role = user?['role'];
    return role == 'superuser' || role == 'admin';
  }

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefsKey);
    if (saved == null || saved.isEmpty) {
      ready = true;
      notifyListeners();
      return;
    }
    token = saved;
    try {
      final me = await ApiService.instance.get('/api/auth/me');
      final map = Map<String, dynamic>.from(me as Map);
      user = Map<String, dynamic>.from(map['user'] as Map);
    } on ApiException catch (error) {
      token = null;
      user = null;
      if (error.statusCode == 401) {
        blockedMessage ??= error.message;
        await prefs.remove(prefsKey);
      } else {
        blockedMessage ??= error.message;
      }
    } catch (error) {
      token = null;
      user = null;
      blockedMessage ??= 'Cannot reach server';
    }
    ready = true;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final decoded = await ApiService.instance.post('/api/auth/login', {
      'username': username.trim(),
      'password': password,
      'device_name': currentDeviceName(),
    });
    final map = Map<String, dynamic>.from(decoded as Map);
    final next = '${map['token'] ?? ''}'.trim();
    if (next.isEmpty) {
      throw ApiException(500, 'Login response did not include a token.');
    }
    token = next;
    user = Map<String, dynamic>.from(map['user'] as Map);
    blockedMessage = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, next);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      if (token != null && token!.isNotEmpty) {
        await ApiService.instance.post('/api/auth/logout', {});
      }
    } catch (_) {}
    await _clearMemory(message: null);
  }

  /// Called when an API response is 401 with a session_* or user_disabled code.
  Future<void> rejectSession(String message) async {
    await _clearMemory(message: message);
  }

  Future<void> _clearMemory({required String? message}) async {
    token = null;
    user = null;
    blockedMessage = message;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    notifyListeners();
  }
}
