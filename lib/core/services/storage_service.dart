import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [SharedPreferences] for the two pieces of session
/// state the app needs to persist across restarts: the JWT and a cached
/// copy of the logged-in user's JSON.
///
/// This is the only class in the app allowed to touch SharedPreferences
/// directly — everything else (services, providers) goes through here.
class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  static const String _tokenKey = 'bloodlink_auth_token';
  static const String _userKey = 'bloodlink_cached_user';
  static const String _onboardingKey = 'bloodlink_onboarding_complete';
  static const String _darkModeKey = 'bloodlink_dark_mode';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _prefsInstance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> saveToken(String token) async {
    final prefs = await _prefsInstance;
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await _prefsInstance;
    return prefs.getString(_tokenKey);
  }

  Future<void> saveUserJson(Map<String, dynamic> user) async {
    final prefs = await _prefsInstance;
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUserJson() async {
    final prefs = await _prefsInstance;
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Clears the JWT and cached user — called on logout or on a 401 from
  /// the backend.
  Future<void> clearSession() async {
    final prefs = await _prefsInstance;
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<bool> hasCompletedOnboarding() async =>
      (await _prefsInstance).getBool(_onboardingKey) ?? false;

  Future<void> completeOnboarding() async =>
      (await _prefsInstance).setBool(_onboardingKey, true);

  Future<bool> getDarkMode() async =>
      (await _prefsInstance).getBool(_darkModeKey) ?? false;

  Future<void> saveDarkMode(bool enabled) async =>
      (await _prefsInstance).setBool(_darkModeKey, enabled);
}
