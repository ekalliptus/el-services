import 'package:shared_preferences/shared_preferences.dart';
import 'package:servicehponline/core/services/supabase_config.dart';

class MaintenanceService {
  static const String _maintenanceTableName = 'system_settings';
  static const String _maintenanceKey = 'is_maintenance_mode';
  static const String _maintenanceTitleKey = 'maintenance_title';
  static const String _maintenanceMessageKey = 'maintenance_message';
  static const String _maintenanceCompletionKey =
      'maintenance_estimated_completion';

  // Local cache key
  static const String _localCacheKey = 'maintenance_check_timestamp';
  static const String _localMaintenanceModeKey = 'is_in_maintenance_mode';
  static const String _localMaintenanceTitleKey = 'maintenance_title';
  static const String _localMaintenanceMessageKey = 'maintenance_message';
  static const String _localMaintenanceCompletionKey =
      'maintenance_estimated_completion';

  // Cache duration in minutes
  static const int _cacheDurationMinutes = 5;

  /// Memeriksa apakah aplikasi dalam mode maintenance
  ///
  /// Memeriksa status dari Supabase dan caching hasil.
  /// Jika `forceCheck` true, maka data akan diambil dari server
  /// meskipun cache masih valid.
  static Future<bool> isInMaintenanceMode({bool forceCheck = false}) async {
    final prefs = await SharedPreferences.getInstance();

    // Cek apakah cache valid dan kita tidak diminta untuk force check
    if (!forceCheck) {
      final lastCheck = prefs.getInt(_localCacheKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheAge = now - lastCheck;

      // Jika cache masih valid (kurang dari durasi cache), gunakan nilai yang di-cache
      if (cacheAge < _cacheDurationMinutes * 60 * 1000) {
        return prefs.getBool(_localMaintenanceModeKey) ?? false;
      }
    }

    try {
      // Ambil data maintenance dari server
      final response = await SupabaseConfig.client
          .from(_maintenanceTableName)
          .select()
          .eq('key', _maintenanceKey)
          .maybeSingle();

      bool isInMaintenance = false;

      if (response != null && response['value'] != null) {
        // Konversi ke boolean
        if (response['value'] == 'true') {
          isInMaintenance = true;
        } else if (response['value'] == true) {
          isInMaintenance = true;
        }

        // Simpan status ke cache
        prefs.setBool(_localMaintenanceModeKey, isInMaintenance);
        prefs.setInt(_localCacheKey, DateTime.now().millisecondsSinceEpoch);

        // Jika dalam maintenance mode, ambil juga detail maintenance
        if (isInMaintenance) {
          await _cacheMaintenanceDetails();
        }
      }

      return isInMaintenance;
    } catch (e) {
      print('Error memeriksa mode maintenance: $e');

      // Jika terjadi error, gunakan nilai cache terakhir jika ada
      return prefs.getBool(_localMaintenanceModeKey) ?? false;
    }
  }

  /// Mengambil detail maintenance dari server dan meng-cache-nya
  static Future<void> _cacheMaintenanceDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Ambil judul maintenance
      final titleResponse = await SupabaseConfig.client
          .from(_maintenanceTableName)
          .select()
          .eq('key', _maintenanceTitleKey)
          .maybeSingle();

      if (titleResponse != null && titleResponse['value'] != null) {
        prefs.setString(
            _localMaintenanceTitleKey, titleResponse['value'].toString());
      }

      // Ambil pesan maintenance
      final messageResponse = await SupabaseConfig.client
          .from(_maintenanceTableName)
          .select()
          .eq('key', _maintenanceMessageKey)
          .maybeSingle();

      if (messageResponse != null && messageResponse['value'] != null) {
        prefs.setString(
            _localMaintenanceMessageKey, messageResponse['value'].toString());
      }

      // Ambil estimasi waktu selesai
      final completionResponse = await SupabaseConfig.client
          .from(_maintenanceTableName)
          .select()
          .eq('key', _maintenanceCompletionKey)
          .maybeSingle();

      if (completionResponse != null && completionResponse['value'] != null) {
        // Simpan string ISO datetime
        prefs.setString(_localMaintenanceCompletionKey,
            completionResponse['value'].toString());
      }
    } catch (e) {
      print('Error caching maintenance details: $e');
    }
  }

  /// Mengaktifkan mode maintenance
  ///
  /// Parameter `title`, `message`, dan `estimatedCompletion` opsional.
  /// Jika tidak disediakan, akan menggunakan nilai default.
  static Future<bool> enableMaintenanceMode({
    String? title,
    String? message,
    DateTime? estimatedCompletion,
  }) async {
    try {
      // Perbaharui atau buat setting maintenance mode
      await _upsertSetting(_maintenanceKey, 'true');

      // Perbaharui judul jika disediakan
      if (title != null) {
        await _upsertSetting(_maintenanceTitleKey, title);
      }

      // Perbaharui pesan jika disediakan
      if (message != null) {
        await _upsertSetting(_maintenanceMessageKey, message);
      }

      // Perbaharui estimasi waktu selesai jika disediakan
      if (estimatedCompletion != null) {
        await _upsertSetting(
            _maintenanceCompletionKey, estimatedCompletion.toIso8601String());
      }

      // Reset cache
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool(_localMaintenanceModeKey, true);
      prefs.setInt(_localCacheKey, DateTime.now().millisecondsSinceEpoch);

      // Cache detail baru
      if (title != null) {
        prefs.setString(_localMaintenanceTitleKey, title);
      }
      if (message != null) {
        prefs.setString(_localMaintenanceMessageKey, message);
      }
      if (estimatedCompletion != null) {
        prefs.setString(_localMaintenanceCompletionKey,
            estimatedCompletion.toIso8601String());
      }

      return true;
    } catch (e) {
      print('Error mengaktifkan mode maintenance: $e');
      return false;
    }
  }

  /// Menonaktifkan mode maintenance
  static Future<bool> disableMaintenanceMode() async {
    try {
      // Update setting di database
      await _upsertSetting(_maintenanceKey, 'false');

      // Reset cache
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool(_localMaintenanceModeKey, false);
      prefs.setInt(_localCacheKey, DateTime.now().millisecondsSinceEpoch);

      return true;
    } catch (e) {
      print('Error menonaktifkan mode maintenance: $e');
      return false;
    }
  }

  /// Mendapatkan detail maintenance yang sudah di-cache
  static Future<Map<String, dynamic>> getMaintenanceDetails() async {
    final prefs = await SharedPreferences.getInstance();

    // Default values
    String title = 'Aplikasi Sedang Maintenance';
    String message =
        'Kami sedang melakukan perbaikan sistem untuk meningkatkan layanan. Silakan kembali lagi nanti.';
    DateTime? estimatedCompletion;

    // Get cached values
    final cachedTitle = prefs.getString(_localMaintenanceTitleKey);
    if (cachedTitle != null && cachedTitle.isNotEmpty) {
      title = cachedTitle;
    }

    final cachedMessage = prefs.getString(_localMaintenanceMessageKey);
    if (cachedMessage != null && cachedMessage.isNotEmpty) {
      message = cachedMessage;
    }

    final cachedCompletion = prefs.getString(_localMaintenanceCompletionKey);
    if (cachedCompletion != null && cachedCompletion.isNotEmpty) {
      try {
        estimatedCompletion = DateTime.parse(cachedCompletion);
      } catch (e) {
        print('Error parsing completion date: $e');
      }
    }

    return {
      'title': title,
      'message': message,
      'estimatedCompletion': estimatedCompletion,
    };
  }

  /// Helper untuk upsert setting ke Supabase
  static Future<void> _upsertSetting(String key, String value) async {
    try {
      // Periksa apakah setting sudah ada
      final existingRecord = await SupabaseConfig.client
          .from(_maintenanceTableName)
          .select()
          .eq('key', key)
          .maybeSingle();

      if (existingRecord != null) {
        // Update existing record
        await SupabaseConfig.client
            .from(_maintenanceTableName)
            .update({'value': value}).eq('key', key);
      } else {
        // Insert new record
        await SupabaseConfig.client.from(_maintenanceTableName).insert({
          'key': key,
          'value': value,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Error upserting setting $key: $e');
      throw e;
    }
  }

  /// Memastikan tabel settings ada
  static Future<void> ensureSettingsTableExists() async {
    try {
      // Coba select untuk mengecek tabel
      await SupabaseConfig.client
          .from(_maintenanceTableName)
          .select('key')
          .limit(1);

      // Jika berhasil, tabel sudah ada
      return;
    } catch (e) {
      // Error bisa terjadi karena tabel tidak ada
      // atau permission issue
      String errorMsg = e.toString();

      if (errorMsg.contains('does not exist') ||
          errorMsg.contains('relation') ||
          errorMsg.contains('not found')) {
        print('Tabel system_settings tidak ditemukan. Perlu membuat tabel.');
        throw Exception(
            'Tabel system_settings tidak ditemukan. Silakan buat tabel terlebih dahulu.');
      } else {
        // Error lain
        print('Error memeriksa tabel system_settings: $e');
        throw e;
      }
    }
  }

  /// Mendapatkan SQL untuk membuat tabel system_settings
  static String getCreateTableSQL() {
    return '''
CREATE TABLE system_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT NOT NULL UNIQUE,
  value TEXT,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Initial settings untuk maintenance mode
INSERT INTO system_settings (key, value, description) 
VALUES 
  ('is_maintenance_mode', 'false', 'Status mode maintenance aplikasi'),
  ('maintenance_title', 'Aplikasi Sedang Maintenance', 'Judul pesan maintenance'),
  ('maintenance_message', 'Kami sedang melakukan perbaikan sistem untuk meningkatkan layanan. Silakan kembali lagi nanti.', 'Pesan untuk user saat maintenance'),
  ('maintenance_estimated_completion', NULL, 'Estimasi waktu selesai maintenance (format ISO date)');
''';
  }
}
