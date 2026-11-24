import 'package:shared_preferences/shared_preferences.dart';

/// Small, non-secret settings that survive restarts: flags, preferences,
/// the email waiting for a code. Never store tokens or money data here.
abstract interface class KeyValueStore {
  String? getString(String key);
  bool? getBool(String key);
  Future<void> setString(String key, String value);
  Future<void> setBool(String key, bool value);
  Future<void> remove(String key);
  Future<void> clear();
}

/// Keys used across the app, in one place so nothing collides.
abstract final class StoreKeys {
  static const hapticsEnabled = 'settings.haptics_enabled';
  static const analyticsConsent = 'privacy.analytics_consent';
  static const pendingEmail = 'auth.pending_email';
  static const mockSession = 'mock.session';
  static const mockProfiles = 'mock.profiles';
}

final class SharedPrefsStore implements KeyValueStore {
  SharedPrefsStore(this._prefs);

  static Future<SharedPrefsStore> create() async => SharedPrefsStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);
  @override
  bool? getBool(String key) => _prefs.getBool(key);
  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);
  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
  @override
  Future<void> remove(String key) => _prefs.remove(key);
  @override
  Future<void> clear() => _prefs.clear();
}

/// In-memory store for tests and previews.
final class MemoryStore implements KeyValueStore {
  MemoryStore([Map<String, Object>? seed]) : _data = {...?seed};

  final Map<String, Object> _data;

  @override
  String? getString(String key) => _data[key] as String?;
  @override
  bool? getBool(String key) => _data[key] as bool?;
  @override
  Future<void> setString(String key, String value) async => _data[key] = value;
  @override
  Future<void> setBool(String key, bool value) async => _data[key] = value;
  @override
  Future<void> remove(String key) async => _data.remove(key);
  @override
  Future<void> clear() async => _data.clear();
}
