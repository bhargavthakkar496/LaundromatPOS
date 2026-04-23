import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import 'backend_serializers.dart';

class SessionStore {
  static const _sessionKey = 'manager_session_v1';
  static const _localeKey = 'app_locale_v1';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<AuthSession?> loadSession() async {
    final raw = await _preferences.getString(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decodeAuthSession(decoded);
  }

  Future<void> saveSession(AuthSession session) async {
    await _preferences.setString(
      _sessionKey,
      jsonEncode(encodeAuthSession(session)),
    );
  }

  Future<void> clearSession() async {
    await _preferences.remove(_sessionKey);
  }

  Future<String?> loadLocaleCode() async {
    final localeCode = await _preferences.getString(_localeKey);
    if (localeCode == null || localeCode.isEmpty) {
      return null;
    }
    return localeCode;
  }

  Future<void> saveLocaleCode(String localeCode) async {
    await _preferences.setString(_localeKey, localeCode);
  }
}
