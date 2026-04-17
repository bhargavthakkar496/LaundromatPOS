import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pos_user.dart';

class SessionStore {
  static const _sessionKey = 'manager_session_v1';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<PosUser?> loadSession() async {
    final raw = await _preferences.getString(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return PosUser(
      id: decoded['id'] as int,
      username: decoded['username'] as String,
      displayName: decoded['displayName'] as String,
      pin: decoded['pin'] as String,
      role: decoded['role'] as String,
    );
  }

  Future<void> saveSession(PosUser user) async {
    await _preferences.setString(
      _sessionKey,
      jsonEncode({
        'id': user.id,
        'username': user.username,
        'displayName': user.displayName,
        'pin': user.pin,
        'role': user.role,
      }),
    );
  }

  Future<void> clearSession() async {
    await _preferences.remove(_sessionKey);
  }
}
