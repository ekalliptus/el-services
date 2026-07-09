import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan aman untuk data sensitif (token admin) menggunakan
/// Keystore (Android) / Keychain (iOS). Menggantikan penyimpanan plaintext
/// di SharedPreferences.
///
/// Menyediakan migrasi otomatis satu kali dari SharedPreferences lama agar
/// sesi admin yang sudah tersimpan tidak hilang setelah update aplikasi.
class SecureStore {
  SecureStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _kAdminSession = 'admin_session';
  static const _kAdminLoggedIn = 'admin_logged_in';

  static Future<void> writeAdminSession(String sessionJson) async {
    await _storage.write(key: _kAdminSession, value: sessionJson);
    await _storage.write(key: _kAdminLoggedIn, value: 'true');
  }

  /// Membaca sesi admin. Bila belum ada di secure storage tapi masih ada di
  /// SharedPreferences (instalasi lama), migrasikan lalu bersihkan yang lama.
  static Future<String?> readAdminSession() async {
    final existing = await _storage.read(key: _kAdminSession);
    if (existing != null) return existing;

    // Migrasi dari penyimpanan plaintext lama.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_kAdminSession);
    final legacyLoggedIn = prefs.getBool(_kAdminLoggedIn) ?? false;
    if (legacy != null && legacyLoggedIn) {
      await writeAdminSession(legacy);
      await prefs.remove(_kAdminSession);
      await prefs.remove(_kAdminLoggedIn);
      return legacy;
    }
    return null;
  }

  static Future<bool> isAdminLoggedIn() async {
    if ((await _storage.read(key: _kAdminLoggedIn)) == 'true') return true;
    // Pertimbangkan sesi lama yang belum dimigrasi.
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(_kAdminLoggedIn) ?? false) &&
        prefs.getString(_kAdminSession) != null;
  }

  static Future<void> clearAdminSession() async {
    await _storage.delete(key: _kAdminSession);
    await _storage.delete(key: _kAdminLoggedIn);
    // Bersihkan juga sisa data lama bila ada.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAdminSession);
    await prefs.remove(_kAdminLoggedIn);
  }
}
