import 'dart:async';
import 'dart:io';
import 'dart:convert'; // Import for utf8
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:servicehponline/core/services/supabase_config.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servicehponline/core/theme/app_colors.dart';
import 'package:servicehponline/core/widgets/widgets.dart';

class AppVersionManagerPage extends StatefulWidget {
  const AppVersionManagerPage({Key? key}) : super(key: key);

  @override
  State<AppVersionManagerPage> createState() => _AppVersionManagerPageState();
}

class _AppVersionManagerPageState extends State<AppVersionManagerPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _versionNameController = TextEditingController();
  final TextEditingController _versionCodeController = TextEditingController();
  final TextEditingController _releaseNotesController = TextEditingController();
  bool _isMandatory = false;
  bool _isLoading = false;
  File? _selectedApkFile;
  List<Map<String, dynamic>> _versions = [];
  Map<String, dynamic>? _latestVersion;
  String? _apkError;
  bool _isBucketCreated = false;
  String? _bucketName;
  bool _isLoadingBucket = false;
  String _bucketStatus = '';

  @override
  void initState() {
    super.initState();

    // Periksa koneksi ke bucket storage
    _loadBucketPreference().then((_) {
      if (_bucketName == null) {
        _checkBucket();
      }
    });

    // Periksa keberadaan tabel versions dan skema
    _checkVersionsTable().then((tableExists) {
      if (tableExists) {
        // Periksa skema tabel
        _checkVersionsTableSchema().then((schemaStatus) {
          final missingColumns = schemaStatus.entries
              .where((entry) => entry.value == false)
              .map((entry) => entry.key)
              .toList();

          if (missingColumns.isNotEmpty) {
            // Ada kolom yang hilang, tampilkan panduan
            _showFixTableSchemaGuide(missingColumns);
          } else {
            // Skema lengkap, muat data versi
            _loadVersions();
          }
        });
      } else {
        // Tabel tidak ada, tampilkan panduan
        _showCreateVersionsTableGuide();
      }
    });
  }

  @override
  void dispose() {
    _versionNameController.dispose();
    _versionCodeController.dispose();
    _releaseNotesController.dispose();
    super.dispose();
  }

  Future<bool> _checkBucket() async {
    print('Memulai pengecekan bucket...');
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    final userEmail = SupabaseConfig.client.auth.currentUser?.email;
    print('User ID: $userId');
    print('User Email: $userEmail');

    // Debug admin status
    await _checkAdminStatus();

    if (!mounted) return false;
    setState(() {
      _isLoadingBucket = true;
      _bucketStatus = 'Memeriksa bucket...';
    });

    try {
      // 1. Cek daftar bucket yang tersedia
      final bucketList = await SupabaseConfig.client.storage.listBuckets();
      print('Jumlah total bucket: ${bucketList.length}');

      for (var bucket in bucketList) {
        print('Bucket ditemukan: ${bucket.name}');
      }

      // 2. Cek keberadaan bucket 'updates'
      bool hasUpdatesBucket = bucketList.any((b) => b.name == 'updates');
      bool hasAppUpdatesBucket = bucketList.any((b) => b.name == 'app_updates');

      String targetBucket = 'updates';
      if (!hasUpdatesBucket && hasAppUpdatesBucket) {
        targetBucket = 'app_updates';
      }

      if (!hasUpdatesBucket && !hasAppUpdatesBucket) {
        print('Tidak ada bucket "updates" atau "app_updates" ditemukan');

        // Coba buat bucket baru 'updates' secara otomatis
        try {
          print('Mencoba membuat bucket "updates" secara otomatis...');
          await SupabaseConfig.client.storage
              .createBucket('updates', const BucketOptions(public: true));
          print('Bucket "updates" berhasil dibuat!');

          // Set target bucket ke 'updates' yang baru dibuat
          targetBucket = 'updates';
          hasUpdatesBucket = true;
        } catch (e) {
          print('Gagal membuat bucket secara otomatis: $e');
          // Tampilkan panduan RLS
          _showRlsPolicyGuide(e.toString(), null);

          if (!mounted) return false;
          setState(() {
            _isLoadingBucket = false;
            _bucketStatus = 'Gagal: $e';
            _bucketName = null;
            _isBucketCreated = false;
          });

          // Hapus nilai bucket dari SharedPreferences
          _clearBucketPreference();

          return false;
        }
      }

      // 3. Cek izin akses ke bucket
      try {
        print('Memeriksa izin akses ke bucket "$targetBucket"...');

        // Lakukan test upload untuk memastikan izin berfungsi
        final testResult = await _testBucketPermissions(targetBucket);
        if (!testResult) {
          throw Exception('Tes izin bucket gagal');
        }

        // Simpan nama bucket ke SharedPreferences untuk digunakan nanti
        await _saveBucketPreference(targetBucket);

        if (!mounted) return false;
        setState(() {
          _isLoadingBucket = false;
          _bucketStatus = 'Terhubung ke bucket "$targetBucket"';
          _bucketName = targetBucket;
          _isBucketCreated =
              true; // Set ke true karena bucket terdeteksi dan dapat diakses
        });

        return true;
      } catch (e) {
        print('Error saat mengakses bucket "$targetBucket": $e');

        // Debug info lebih lanjut untuk membantu pemecahan masalah
        await _debugBucketPermissions();

        // Tampilkan panduan RLS
        _showRlsPolicyGuide(e.toString(), targetBucket);

        if (!mounted) return false;
        setState(() {
          _isLoadingBucket = false;
          _bucketStatus =
              'Tidak dapat mengakses bucket. Periksa kebijakan RLS.';
          _bucketName = null;
          _isBucketCreated = false;
        });

        // Hapus nilai bucket dari SharedPreferences
        _clearBucketPreference();

        return false;
      }
    } catch (e) {
      print('Error checking bucket: $e');
      if (!mounted) return false;
      setState(() {
        _isLoadingBucket = false;
        _bucketStatus = 'Error: $e';
        _bucketName = null;
        _isBucketCreated = false;
      });

      // Hapus nilai bucket dari SharedPreferences
      _clearBucketPreference();

      return false;
    }
  }

  // Metode untuk menguji izin bucket dengan mencoba upload dan hapus file
  Future<bool> _testBucketPermissions(String bucketName) async {
    try {
      print('Menguji izin bucket dengan upload file kecil...');
      final testFileName =
          'test_permission_${DateTime.now().millisecondsSinceEpoch}.txt';

      // Coba upload file kecil
      await SupabaseConfig.client.storage.from(bucketName).uploadBinary(
            testFileName,
            Uint8List.fromList(utf8.encode('test permission')),
            fileOptions: const FileOptions(contentType: 'text/plain'),
          );
      print('Upload test file berhasil');

      // Coba hapus file
      await SupabaseConfig.client.storage
          .from(bucketName)
          .remove([testFileName]);
      print('Hapus test file berhasil');

      return true;
    } catch (e) {
      print('Tes izin bucket gagal: $e');
      return false;
    }
  }

  // Metode pembantu untuk debugging status admin
  Future<void> _checkAdminStatus() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) {
      print('DEBUG: User belum login, tidak dapat memeriksa status admin');
      return;
    }

    try {
      print('DEBUG: Memeriksa status admin untuk user ID: $userId');
      final response = await SupabaseConfig.client
          .from('admins')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        final bool isSuperAdmin = response['role'] == 'super_admin';
        print('DEBUG: User ditemukan di tabel admins');
        print('DEBUG: Status super admin: $isSuperAdmin');
        print('DEBUG: Data admin: ${response.toString()}');
      } else {
        print('DEBUG: User TIDAK ditemukan di tabel admins!');
      }
    } catch (e) {
      print('DEBUG: Error saat memeriksa status admin: ${e.toString()}');
    }
  }

  // Debug informasi lebih lanjut tentang bucket permissions
  Future<void> _debugBucketPermissions() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;

    print('DEBUG BUCKET PERMISSIONS');
    print('------------------------');
    print('User ID: $userId');
    print(
        'Auth Status: ${SupabaseConfig.client.auth.currentSession != null ? "Login" : "Tidak Login"}');

    try {
      // Cek apakah user ada di tabel admins
      final adminResponse = await SupabaseConfig.client
          .from('admins')
          .select('*')
          .eq('id', userId ?? '')
          .maybeSingle();

      print('Admin Query Response:');
      print('Data: $adminResponse');

      if (adminResponse != null) {
        print('Admin data: $adminResponse');
      } else {
        print(
            'WARNING: User tidak ditemukan di tabel admins atau tabel kosong!');
      }

      // Cek semua user di tabel admins - tidak lagi mencoba mengambil email
      final allAdminsResponse = await SupabaseConfig.client
          .from('admins')
          .select('id, role, user_id')
          .limit(10);

      print('Semua Admin:');
      print('Total admin: ${allAdminsResponse.length}');

      if (allAdminsResponse.isNotEmpty) {
        for (var admin in allAdminsResponse) {
          print(
              'Admin ID: ${admin['id']}, User ID: ${admin['user_id']}, Role: ${admin['role']}');
        }
      }
    } catch (e) {
      print('Error saat debugging permissions: ${e.toString()}');
    }
  }

  void _showRlsPolicyGuide(String errorDetails, String? bucketName) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Masalah Izin RLS - Detail Debugging'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bucketName != null
                        ? 'Bucket "$bucketName" sudah ada, tapi Anda tidak memiliki izin untuk mengaksesnya. Ini masalah kebijakan Row-Level Security (RLS).'
                        : 'Anda tidak memiliki izin untuk mengakses bucket storage. Ini masalah kebijakan Row-Level Security (RLS).',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text('Debugging Info:'),
                  Text(
                      '• User ID: ${SupabaseConfig.client.auth.currentUser?.id ?? "Tidak ada"}'),
                  Text(
                      '• User Email: ${SupabaseConfig.client.auth.currentUser?.email ?? "Tidak ada"}'),
                  Text('• Bucket: ${bucketName ?? "Tidak ada"}'),
                  SizedBox(height: 16),
                  Text('Langkah-langkah perbaikan:'),
                  SizedBox(height: 8),
                  Text('1. Periksa user ID di tabel "admins":'),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    child: SelectableText(
                      'SELECT * FROM admins WHERE id = \'${SupabaseConfig.client.auth.currentUser?.id ?? ""}\';',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('2. Pastikan role bernilai super_admin:'),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    child: SelectableText(
                      'UPDATE admins SET role = \'super_admin\' WHERE id = \'${SupabaseConfig.client.auth.currentUser?.id ?? ""}\';',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('3. Periksa bucket yang tersedia:'),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    child: SelectableText(
                      'SELECT name FROM storage.buckets;',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('4. Tambahkan atau perbaiki kebijakan RLS:'),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    child: SelectableText(
                      'CREATE POLICY "Super Admin dapat mengakses storage" ON storage.objects FOR ALL USING (auth.uid() IN (SELECT id FROM admins WHERE role = \'super_admin\'));',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Detail Error:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Container(
                    padding: EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.error),
                    ),
                    child: SelectableText(
                      errorDetails,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catatan Penting:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• Buat bucket dengan nama "updates" (bukan "update" atau nama lain)',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• Bucket harus dibuat sebagai public bucket',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• User ID di tabel admins harus sama persis dengan auth.uid()',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• Kebijakan RLS harus diterapkan pada object, bukan bucket',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• Kolom "role" harus memiliki nilai "super_admin" untuk admin dengan akses penuh',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text('Tutup'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                child: Text('Cek Koneksi Lagi'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _checkBucket();
                },
              ),
            ],
          ),
        );
      }
    });
  }

  Future<void> _loadVersions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Memuat data versi aplikasi dari tabel versions...');

      // Periksa apakah tabel versions ada
      final hasVersionsTable = await _checkVersionsTable();
      if (!hasVersionsTable) {
        // Tabel tidak ada, tampilkan panduan
        _showCreateVersionsTableGuide();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Periksa apakah skema tabel sesuai dengan yang diharapkan
      final schemaStatus = await _checkVersionsTableSchema();
      final missingColumns = schemaStatus.entries
          .where((entry) => entry.value == false)
          .map((entry) => entry.key)
          .toList();

      // Periksa kolom yang sangat penting (wajib ada)
      final criticalColumns = [
        'latest_version_name',
        'latest_version_code',
        'platform',
      ];

      final missingCriticalColumns = criticalColumns
          .where((column) => schemaStatus[column] == false)
          .toList();

      if (missingCriticalColumns.isNotEmpty) {
        // Ada kolom kritis yang hilang, tampilkan panduan
        _showFixTableSchemaGuide(missingColumns);
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Jika ada kolom tidak kritis yang hilang, cukup tampilkan peringatan
      if (missingColumns.isNotEmpty && mounted) {
        // Tampilkan peringatan tapi tetap lanjutkan
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Beberapa kolom tidak tersedia di tabel versions: ${missingColumns.join(", ")}'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'PERBAIKI',
              textColor: Theme.of(context).colorScheme.onPrimary,
              onPressed: () {
                _showFixTableSchemaGuide(missingColumns);
              },
            ),
          ),
        );
      }

      // Tentukan kolom yang akan diambil berdasarkan yang tersedia
      final List<String> columnsToSelect = ['id'];

      // Tambahkan kolom yang tersedia ke query
      for (final entry in schemaStatus.entries) {
        if (entry.value == true) {
          columnsToSelect.add(entry.key);
        }
      }

      final selectQuery = columnsToSelect.join(',');
      print('Memilih kolom: $selectQuery');

      // Gunakan query dengan kolom yang tersedia
      final versions = await SupabaseConfig.client
          .from('versions')
          .select(selectQuery)
          .eq('platform', 'android')
          .order('latest_version_code', ascending: false)
          .limit(10); // Tambahkan limit untuk debugging

      print('Data versi berhasil dimuat. Jumlah data: ${versions.length}');

      if (versions.isNotEmpty) {
        print('DEBUG: Data versi terbaru dari query:');
        print(versions[0]);
      } else {
        print('Belum ada data versi aplikasi');
      }

      // Debug: periksa sorting
      if (versions.length > 1) {
        print('DEBUG: Urutan 2 versi teratas:');
        print(
            '1. ${versions[0]['latest_version_name']} (${versions[0]['latest_version_code']})');
        print(
            '2. ${versions[1]['latest_version_name']} (${versions[1]['latest_version_code']})');
      }

      if (!mounted) return;
      setState(() {
        _versions = List<Map<String, dynamic>>.from(versions);
        if (_versions.isNotEmpty) {
          _latestVersion = _versions.first;

          // Debug: verifikasi data yang akan digunakan
          print('DEBUG: Versi terbaru yang akan ditampilkan:');
          print('Nama: ${_latestVersion!['latest_version_name']}');
          print('Kode: ${_latestVersion!['latest_version_code']}');

          _versionNameController.text =
              _getNextVersionName(_latestVersion!['latest_version_name']);
          _versionCodeController.text =
              (_latestVersion!['latest_version_code'] + 1).toString();

          print(
              'Versi terbaru terdeteksi: ${_latestVersion!['latest_version_name']} (code: ${_latestVersion!['latest_version_code']})');
          print(
              'Rekomendasi versi berikutnya: ${_versionNameController.text} (code: ${_versionCodeController.text})');
        } else {
          // Default values jika belum ada versi
          _versionNameController.text = '1.0.0';
          _versionCodeController.text = '1';
          print(
              'Tidak ada versi sebelumnya, menggunakan nilai default: 1.0.0 (code: 1)');
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading versions: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      String errorMessage = 'Gagal memuat data versi aplikasi: ${e.toString()}';

      // Periksa apakah error terkait dengan kolom yang tidak ditemukan
      if (e.toString().contains('Could not find') &&
          e.toString().contains('column')) {
        final columnName = _extractColumnNameFromError(e.toString());
        errorMessage =
            'Kolom "$columnName" tidak ditemukan di tabel versions. Silakan tambahkan kolom yang hilang.';

        // Coba periksa skema lagi dan tampilkan panduan
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkVersionsTableSchema().then((schemaStatus) {
            final missingColumns = schemaStatus.entries
                .where((entry) => entry.value == false)
                .map((entry) => entry.key)
                .toList();

            if (missingColumns.isNotEmpty) {
              _showFixTableSchemaGuide(missingColumns);
            }
          });
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // Menampilkan dialog cara membuat tabel versions
  void _showCreateVersionsTableGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tabel Versions Belum Ada'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tabel "versions" belum ada di database. Tabel ini diperlukan untuk menyimpan data versi aplikasi.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('SQL untuk membuat tabel versions:'),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: SelectableText(
                  '''CREATE TABLE versions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  latest_version_name TEXT NOT NULL,
  latest_version_code INTEGER NOT NULL,
  release_notes TEXT,
  platform TEXT NOT NULL,
  apk_download_url TEXT,
  file_hash TEXT,
  file_size INTEGER,
  is_mandatory BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  published_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);''',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text('Jalankan SQL ini di SQL Editor di dashboard Supabase.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('TUTUP'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Coba cek lagi apakah tabel sudah dibuat
              final tableExists = await _checkVersionsTable();
              if (tableExists) {
                // Tabel sudah dibuat, muat versi aplikasi
                _loadVersions();
              }
            },
            child: Text('COBA LAGI'),
          ),
        ],
      ),
    );
  }

  String _getNextVersionName(String currentVersion) {
    print('Menghitung versi berikutnya berdasarkan: $currentVersion');
    final parts = currentVersion.split('.');

    // Pastikan format versi valid (x.y.z)
    if (parts.length < 3) {
      print(
          'Format versi tidak standar, menambahkan .0 jika kurang dari 3 bagian');
      while (parts.length < 3) {
        parts.add('0');
      }
    }

    try {
      // Parse semua bagian sebagai integer
      final major = int.parse(parts[0]);
      final minor = int.parse(parts[1]);
      final patch = int.parse(parts[2]);

      // Strategi increment: tambah 0.1.0 (naikkan minor version)
      final nextMinor = minor + 1;
      final nextVersion = '$major.$nextMinor.0';

      print(
          'Versi saat ini: $major.$minor.$patch -> Versi berikutnya: $nextVersion');
      return nextVersion;
    } catch (e) {
      // Jika gagal parse, gunakan strategi fallback
      print('Gagal parse versi, menggunakan strategi fallback: $e');
      if (parts.length >= 2) {
        try {
          // Coba tambahkan ke bagian kedua saja
          final secondPart = int.tryParse(parts[1]) ?? 0;
          parts[1] = (secondPart + 1).toString();
          parts[2] = '0'; // Reset patch version
          return parts.join('.');
        } catch (e) {
          print('Fallback juga gagal: $e');
          // Jika masih gagal, tambahkan .1 saja
          return '$currentVersion.1';
        }
      } else {
        return '$currentVersion.1';
      }
    }
  }

  Future<void> _selectApkFile() async {
    try {
      // Pada Android, gunakan image_picker sebagai fallback
      File? selectedFile;

      try {
        // Gunakan file_selector untuk memilih berkas .apk.
        final XTypeGroup typeGroup = XTypeGroup(
          label: 'APK files',
          extensions: ['apk'],
        );
        final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
        if (file != null) {
          selectedFile = File(file.path);
        }
      } catch (e) {
        // Jangan fallback ke image_picker: hanya memunculkan gambar, tidak
        // dapat memilih APK sehingga selalu ditolak oleh cek ekstensi.
        print('File selector gagal: $e');
        if (!mounted) return;
        setState(() {
          _apkError =
              'Tidak dapat membuka pemilih berkas. Pastikan aplikasi file '
              'tersedia untuk memilih berkas .apk.';
        });
        return;
      }

      if (selectedFile == null) return;

      // Periksa nama file
      final String fileName = path.basename(selectedFile.path).toLowerCase();
      if (!fileName.endsWith('.apk')) {
        setState(() {
          _apkError = 'File harus berakhiran .apk';
        });
        return;
      }

      // Verifikasi lebih lanjut bahwa file adalah APK yang valid
      try {
        // Periksa ukuran file
        final fileSize = await selectedFile.length();
        if (!mounted) return;
        if (fileSize <= 0 || fileSize > 100 * 1024 * 1024) {
          // Max 100MB
          setState(() {
            _apkError = 'Ukuran file tidak valid (maks. 100MB)';
          });
          return;
        }

        // Periksa magic number untuk ZIP/APK
        final bytes = await selectedFile.openRead(0, 50).toList();
        if (!mounted) return;
        if (bytes.isEmpty) {
          setState(() {
            _apkError = 'Gagal membaca file';
          });
          return;
        }

        final List<int> flatBytes = bytes.expand((x) => x).toList();
        if (flatBytes.length < 4 ||
            flatBytes[0] != 0x50 || // P
            flatBytes[1] != 0x4B || // K
            flatBytes[2] != 0x03 || // Control Z
            flatBytes[3] != 0x04) {
          // EOT
          setState(() {
            _apkError = 'File bukan merupakan APK valid';
          });
          return;
        }
      } catch (e) {
        print('Error verifying APK: $e');
        if (!mounted) return;
        setState(() {
          _apkError = 'Gagal memverifikasi file: $e';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _selectedApkFile = selectedFile;
        _apkError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('File APK dipilih: ${path.basename(selectedFile.path)}'),
        ),
      );
    } catch (e) {
      print('Error selecting file: $e');
      if (!mounted) return;
      setState(() {
        _apkError = 'Gagal memilih file: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih file')),
      );
    }
  }

  Future<void> _publishVersion() async {
    if (_selectedApkFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anda harus memilih file APK terlebih dahulu')),
      );
      return;
    }

    if (_versionNameController.text.isEmpty ||
        _versionCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Nama versi dan kode versi harus diisi terlebih dahulu')),
      );
      return;
    }

    if (_bucketName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Bucket storage belum tersedia. Silakan periksa koneksi storage terlebih dahulu')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Periksa skema tabel terlebih dahulu
      final schemaStatus = await _checkVersionsTableSchema();
      final missingColumns = schemaStatus.entries
          .where((entry) => entry.value == false)
          .map((entry) => entry.key)
          .toList();

      // Periksa kolom yang sangat penting (wajib ada)
      final criticalColumns = [
        'latest_version_name',
        'latest_version_code',
        'platform',
        'apk_download_url'
      ];

      final missingCriticalColumns = criticalColumns
          .where((column) => schemaStatus[column] == false)
          .toList();

      if (missingCriticalColumns.isNotEmpty) {
        // Ada kolom kritis yang hilang, harus ditambahkan
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Kolom penting tidak ditemukan: ${missingCriticalColumns.join(", ")}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );

        _showFixTableSchemaGuide(missingColumns);
        return;
      }

      // Periksa kolom opsional yang saat ini akan digunakan
      final optionalColumnsInUse = <String>[];

      if (_releaseNotesController.text.isNotEmpty &&
          schemaStatus['release_notes'] == false) {
        optionalColumnsInUse.add('release_notes');
      }

      if (schemaStatus['file_hash'] == false) {
        optionalColumnsInUse.add('file_hash');
      }

      if (schemaStatus['file_size'] == false) {
        optionalColumnsInUse.add('file_size');
      }

      if (schemaStatus['published_at'] == false) {
        optionalColumnsInUse.add('published_at');
      }

      // Sertakan is_mandatory bila kolomnya tidak ada, agar admin tahu flag
      // "pembaruan wajib" tidak akan tersimpan (sebelumnya di-drop diam-diam).
      if (schemaStatus['is_mandatory'] == false && _isMandatory) {
        optionalColumnsInUse.add('is_mandatory');
      }

      if (optionalColumnsInUse.isNotEmpty) {
        // Tanyakan user apakah ingin melanjutkan tanpa kolom opsional
        bool continueWithoutOptionalColumns =
            await _showConfirmMissingColumnsDialog(optionalColumnsInUse);
        if (!mounted) return;

        if (!continueWithoutOptionalColumns) {
          setState(() {
            _isLoading = false;
          });
          _showFixTableSchemaGuide(missingColumns);
          return;
        }

        // Jika user memilih melanjutkan, tampilkan peringatan bahwa beberapa data tidak akan disimpan
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Beberapa data tidak akan disimpan karena kolom tidak tersedia'),
            backgroundColor: AppColors.warning,
          ),
        );
      }

      final apkFileName =
          'v${_versionNameController.text.replaceAll('.', '_')}_${DateTime.now().millisecondsSinceEpoch}.apk';

      // 1. Upload file APK ke Storage
      final fileBytes = await _selectedApkFile!.readAsBytes();
      final String filePath = 'android/$apkFileName';

      // Hitung hash dan ukuran file untuk verifikasi
      final fileHash = sha256.convert(fileBytes).toString();
      final fileSize = fileBytes.length;

      // Pastikan bucketName tidak null dengan menggunakan nilai yang sudah divalidasi
      final String bucketName = _bucketName!;

      // Upload ke bucket storage
      await SupabaseConfig.client.storage.from(bucketName).uploadBinary(
            filePath,
            Uint8List.fromList(fileBytes),
            fileOptions: FileOptions(
              contentType: 'application/vnd.android.package-archive',
            ),
          );

      // 2. Dapatkan URL publik untuk download
      final String downloadUrl =
          SupabaseConfig.client.storage.from(bucketName).getPublicUrl(filePath);

      // Siapkan data untuk dimasukkan, dengan kolom yang pasti ada
      final Map<String, dynamic> insertData = {
        'latest_version_name': _versionNameController.text,
        'latest_version_code': int.parse(_versionCodeController.text),
        'platform': 'android',
        'apk_download_url': downloadUrl,
      };

      // Tambahkan data opsional hanya jika kolom ada
      if (schemaStatus['release_notes'] == true &&
          _releaseNotesController.text.isNotEmpty) {
        insertData['release_notes'] = _releaseNotesController.text;
      }

      if (schemaStatus['file_hash'] == true) {
        insertData['file_hash'] = fileHash;
      }

      if (schemaStatus['file_size'] == true) {
        insertData['file_size'] = fileSize;
      }

      if (schemaStatus['is_mandatory'] == true) {
        insertData['is_mandatory'] = _isMandatory;
      }

      if (schemaStatus['published_at'] == true) {
        insertData['published_at'] = DateTime.now().toIso8601String();
      }

      // 3. Simpan data versi ke database - dengan data yang disesuaikan
      await SupabaseConfig.client.from('versions').insert(insertData);

      // 4. Reset form dan reload data
      if (!mounted) return;
      setState(() {
        _selectedApkFile = null;
        _versionNameController.clear();
        _versionCodeController.clear();
        _releaseNotesController.clear();
        _isMandatory = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Versi baru berhasil ditambahkan')),
      );

      _loadVersions();
    } catch (e) {
      print('Error uploading version: $e');
      if (!mounted) return;

      String errorMessage = 'Gagal upload versi baru: ${e.toString()}';

      // Periksa apakah error terkait dengan kolom yang tidak ditemukan
      if (e.toString().contains('Could not find') &&
          e.toString().contains('column')) {
        final columnName = _extractColumnNameFromError(e.toString());
        errorMessage =
            'Kolom "$columnName" tidak ditemukan di tabel versions. Silakan tambahkan kolom yang hilang.';

        // Coba periksa skema lagi dan tampilkan panduan
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkVersionsTableSchema().then((schemaStatus) {
            final missingColumns = schemaStatus.entries
                .where((entry) => entry.value == false)
                .map((entry) => entry.key)
                .toList();

            if (missingColumns.isNotEmpty) {
              _showFixTableSchemaGuide(missingColumns);
            }
          });
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Ekstrak nama kolom dari pesan error
  String _extractColumnNameFromError(String errorMessage) {
    // Coba ekstrak nama kolom dari berbagai format pesan error
    final regexFind =
        RegExp(r"Could not find the '([^']+)'").firstMatch(errorMessage);
    if (regexFind != null && regexFind.groupCount >= 1) {
      return regexFind.group(1) ?? 'unknown';
    }

    final regexColumn = RegExp(r"column versions\.([^\s]+) does not exist")
        .firstMatch(errorMessage);
    if (regexColumn != null && regexColumn.groupCount >= 1) {
      return regexColumn.group(1) ?? 'unknown';
    }

    return 'unknown';
  }

  // Dialog konfirmasi untuk melanjutkan tanpa kolom opsional
  Future<bool> _showConfirmMissingColumnsDialog(
      List<String> missingColumns) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Peringatan Kolom Tidak Tersedia'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Beberapa kolom tidak tersedia di tabel versions. Informasi berikut tidak akan disimpan:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  ...missingColumns.map((column) => Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 4),
                        child: Text(
                          '• $column',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      )),
                  SizedBox(height: 16),
                  Text(
                      'Anda masih bisa melanjutkan tanpa kolom ini, tetapi beberapa informasi tidak akan disimpan.'),
                  SizedBox(height: 8),
                  Text(
                    'Rekomendasi: Tambahkan kolom yang hilang untuk penyimpanan data yang lengkap.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('BATAL'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('LANJUTKAN TANPA KOLOM INI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kelola Versi Aplikasi',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Tambahkan tombol untuk memeriksa koneksi storage
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Periksa Koneksi Storage',
            onPressed: _isLoading
                ? null
                : () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Memeriksa koneksi ke storage Supabase...')),
                    );
                    await _checkBucket();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isBucketCreated
                            ? 'Koneksi ke bucket storage berhasil!'
                            : 'Gagal terhubung ke bucket storage'),
                        backgroundColor: _isBucketCreated
                            ? AppColors.success
                            : Theme.of(context).colorScheme.error,
                      ),
                    );
                  },
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status koneksi bucket
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isBucketCreated
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isBucketCreated
                            ? AppColors.success.withValues(alpha: 0.5)
                            : AppColors.warning.withValues(alpha: 0.5),
                      ),
                    ),
                    child: _isLoadingBucket
                        ? Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Memeriksa koneksi ke bucket storage...',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(
                                _isBucketCreated
                                    ? Icons.cloud_done
                                    : Icons.cloud_off,
                                color: _isBucketCreated
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Status Storage',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _bucketStatus,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_isBucketCreated)
                                ElevatedButton.icon(
                                  icon: Icon(Icons.refresh, size: 16),
                                  label: Text('Coba Lagi'),
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    minimumSize: Size(0, 0),
                                    textStyle: TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => _checkBucket(),
                                ),
                            ],
                          ),
                  ),
                  SizedBox(height: 16),
                  if (_latestVersion != null) ...[
                    AnrCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Versi Terbaru',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.refresh),
                                tooltip: 'Muat ulang data versi',
                                onPressed: _loadVersions,
                              )
                            ],
                          ),
                          SizedBox(height: 8),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Versi: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text:
                                      '${_latestVersion!['latest_version_name']} ',
                                ),
                                TextSpan(
                                  text:
                                      '(kode: ${_latestVersion!['latest_version_code']})',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 4),
                          if (_latestVersion!.containsKey('is_mandatory'))
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Status: ',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text:
                                        _latestVersion!['is_mandatory'] == true
                                            ? 'Wajib'
                                            : 'Opsional',
                                    style: TextStyle(
                                      color: _latestVersion!['is_mandatory'] ==
                                              true
                                          ? Theme.of(context).colorScheme.error
                                          : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Tanggal Rilis: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: (() {
                                    final parsed = DateTime.tryParse(
                                        _latestVersion!['created_at']
                                                ?.toString() ??
                                            '');
                                    return parsed != null
                                        ? DateFormat('dd MMM yyyy, HH:mm')
                                            .format(parsed.toLocal())
                                        : 'Tidak tersedia';
                                  })(),
                                ),
                              ],
                            ),
                          ),
                          if (_latestVersion!.containsKey('file_size') &&
                              _latestVersion!['file_size'] != null) ...[
                            SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Ukuran File: ',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: _formatFileSize(
                                        _latestVersion!['file_size']),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_latestVersion!.containsKey('release_notes') &&
                              _latestVersion!['release_notes'] != null) ...[
                            SizedBox(height: 8),
                            Text(
                              'Catatan Rilis:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_latestVersion!['release_notes']),
                            ),
                          ],
                          if (_latestVersion!.containsKey('apk_download_url') &&
                              _latestVersion!['apk_download_url'] != null) ...[
                            SizedBox(height: 8),
                            OutlinedButton.icon(
                              icon: Icon(Icons.download),
                              label: Text('Unduh APK'),
                              onPressed: () async {
                                final url = _latestVersion!['apk_download_url'];
                                // Buka URL di browser
                                try {
                                  await Clipboard.setData(
                                      ClipboardData(text: url));
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'URL download disalin ke clipboard')),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Gagal menyalin URL: $e')),
                                  );
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  AnrCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnrSectionHeader(title: 'Tambah Versi Baru'),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _versionNameController,
                            decoration: InputDecoration(
                              labelText: 'Nama Versi (misalnya: 1.0.0)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Nama versi harus diisi';
                              }
                              final RegExp versionRegex =
                                  RegExp(r'^\d+\.\d+\.\d+$');
                              if (!versionRegex.hasMatch(value)) {
                                return 'Format versi harus x.y.z (misal: 1.0.0)';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _versionCodeController,
                            decoration: InputDecoration(
                              labelText:
                                  'Kode Versi (angka, harus lebih besar dari versi sebelumnya)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Kode versi harus diisi';
                              }
                              final int? code = int.tryParse(value);
                              if (code == null) {
                                return 'Kode versi harus berupa angka';
                              }
                              if (_latestVersion != null &&
                                  code <=
                                      _latestVersion!['latest_version_code']) {
                                return 'Kode versi harus lebih besar dari versi sebelumnya (${_latestVersion!['latest_version_code']})';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _releaseNotesController,
                            decoration: InputDecoration(
                              labelText: 'Catatan Rilis',
                              border: OutlineInputBorder(),
                              hintText:
                                  'Masukkan informasi tentang fitur atau perbaikan di versi ini',
                            ),
                            maxLines: 5,
                          ),
                          SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _selectApkFile,
                            icon: Icon(Icons.file_upload),
                            label: Text(_selectedApkFile == null
                                ? 'Pilih File APK'
                                : 'APK Terpilih: ${path.basename(_selectedApkFile!.path)}'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(double.infinity, 56),
                            ),
                          ),
                          if (_apkError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _apkError!,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12),
                              ),
                            ),
                          if (_selectedApkFile != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Ukuran File: ${_formatFileSize(_selectedApkFile!.lengthSync())}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ),
                            ),
                          SizedBox(height: 16),
                          CheckboxListTile(
                            title: Text('Pembaruan Wajib'),
                            subtitle: Text(
                              'Jika dicentang, pengguna harus menginstal pembaruan ini untuk terus menggunakan aplikasi',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _isMandatory,
                            onChanged: (value) {
                              setState(() {
                                _isMandatory = value ?? false;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          SizedBox(height: 24),
                          AnrButton(
                            label: 'Unggah dan Simpan Versi Baru',
                            onPressed: _publishVersion,
                            loading: _isLoading,
                            icon: Icons.cloud_upload_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes bytes';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Menyimpan nama bucket ke SharedPreferences
  Future<void> _saveBucketPreference(String bucketName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_update_bucket_name', bucketName);
      print('Bucket name "$bucketName" saved to preferences');
    } catch (e) {
      print('Error saving bucket preference: $e');
    }
  }

  // Menghapus nama bucket dari SharedPreferences
  Future<void> _clearBucketPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_update_bucket_name');
      print('Bucket name removed from preferences');
    } catch (e) {
      print('Error clearing bucket preference: $e');
    }
  }

  // Load bucket name dari SharedPreferences
  Future<void> _loadBucketPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBucketName = prefs.getString('app_update_bucket_name');

      if (savedBucketName != null && savedBucketName.isNotEmpty) {
        print('Found saved bucket name: $savedBucketName');
        if (!mounted) return;
        setState(() {
          _bucketName = savedBucketName;
          _bucketStatus =
              'Menggunakan bucket "$savedBucketName" dari sesi sebelumnya';
          _isBucketCreated = true;
        });

        // Verifikasi bucket masih bisa diakses
        _verifyBucketAccess(savedBucketName);
      }
    } catch (e) {
      print('Error loading bucket preference: $e');
    }
  }

  // Verifikasi akses bucket dari SharedPreferences
  Future<void> _verifyBucketAccess(String bucketName) async {
    print('Verifying bucket access for: $bucketName');
    try {
      final testResult = await _testBucketPermissions(bucketName);
      if (!testResult) {
        print('Bucket verification failed, running full check');
        _checkBucket(); // Lakukan pengecekan lengkap jika verifikasi gagal
      }
    } catch (e) {
      print('Error verifying bucket access: $e');
      _checkBucket(); // Lakukan pengecekan lengkap jika terjadi error
    }
  }

  // Fungsi untuk memeriksa keberadaan tabel versions
  Future<bool> _checkVersionsTable() async {
    try {
      print('Memeriksa keberadaan tabel versions...');
      await SupabaseConfig.client.from('versions').select('count').limit(1);

      print('Tabel versions ditemukan!');
      // Tabel ditemukan, periksa skema
      return true;
    } catch (e) {
      if (e.toString().contains('relation "versions" does not exist')) {
        print('Tabel versions tidak ditemukan.');
        return false;
      } else {
        print('Error saat memeriksa tabel versions: $e');
        // Error lain, anggap tabel ada
        return true;
      }
    }
  }

  // Fungsi untuk memeriksa skema tabel versions
  Future<Map<String, bool>> _checkVersionsTableSchema() async {
    try {
      print('Memeriksa skema tabel versions...');

      // Daftar kolom yang diharapkan ada di tabel versions
      final requiredColumns = [
        'latest_version_name',
        'latest_version_code',
        'platform',
        'apk_download_url',
        'file_hash',
        'file_size',
        'is_mandatory',
        'release_notes',
        'published_at',
        'created_at'
      ];

      // Buat map untuk melacak status setiap kolom
      final columnStatus = <String, bool>{};
      for (final column in requiredColumns) {
        columnStatus[column] = false; // Default false sampai terbukti ada
      }

      // Optimasi: coba satu round-trip yang memilih SEMUA kolom sekaligus.
      // Bila berhasil, seluruh kolom ada. Hanya jika gagal (mis. ada kolom
      // hilang) kita jatuh ke pemeriksaan per-kolom untuk tahu mana yang hilang.
      try {
        await SupabaseConfig.client
            .from('versions')
            .select(requiredColumns.join(','))
            .limit(1);
        for (final column in requiredColumns) {
          columnStatus[column] = true;
        }
        print('Skema tabel versions lengkap (single-query).');
        return columnStatus;
      } catch (_) {
        // Lanjut ke pemeriksaan per-kolom di bawah.
      }

      // Fallback: periksa keberadaan tiap kolom satu per satu.
      for (final column in requiredColumns) {
        try {
          // Query untuk memeriksa keberadaan kolom
          await SupabaseConfig.client.from('versions').select(column).limit(1);

          // Jika sampai di sini, kolom ada
          columnStatus[column] = true;
          print('Kolom $column ditemukan');
        } catch (e) {
          String errorMsg = e.toString();
          // Periksa secara spesifik pesan error PostgreSQL untuk kolom yang tidak ada
          if (errorMsg.contains('column versions.$column does not exist') ||
              errorMsg.contains('Could not find the \'$column\' column')) {
            columnStatus[column] = false;
            print('Kolom $column TIDAK ditemukan: $e');
          } else {
            // Error lain yang tidak berkaitan dengan tidak adanya kolom (mungkin koneksi, dll)
            print('Error saat memeriksa kolom $column: $e');
            // Jika error bukan karena kolom tidak ada, biarkan status tetap false (untuk keamanan)
          }
        }
      }

      // Cek apakah semua kolom yang diperlukan ada
      final missingColumns = columnStatus.entries
          .where((entry) => entry.value == false)
          .map((entry) => entry.key)
          .toList();

      if (missingColumns.isNotEmpty) {
        print(
            'Skema tabel versions tidak lengkap. Kolom yang hilang: $missingColumns');
      } else {
        print('Skema tabel versions lengkap! Semua kolom dibutuhkan tersedia.');
      }

      return columnStatus;
    } catch (e) {
      print('Error memeriksa skema tabel versions: $e');
      return {};
    }
  }

  // Menampilkan panduan cara memperbaiki skema tabel versions
  void _showFixTableSchemaGuide(List<String> missingColumns) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Skema Tabel Versions Tidak Lengkap'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tabel "versions" tidak memiliki semua kolom yang diperlukan. Kolom berikut perlu ditambahkan:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ...missingColumns.map((column) => Padding(
                    padding: EdgeInsets.only(left: 16, bottom: 4),
                    child: Text('• $column',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  )),
              SizedBox(height: 16),
              Text('SQL untuk menambahkan kolom yang hilang:'),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: SelectableText(
                  _generateAlterTableSQL(missingColumns),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text('Alternatif: SQL untuk membuat ulang tabel versions:'),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: SelectableText(
                  '''DROP TABLE IF EXISTS versions;
CREATE TABLE versions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  latest_version_name TEXT NOT NULL,
  latest_version_code INTEGER NOT NULL,
  release_notes TEXT,
  platform TEXT NOT NULL,
  apk_download_url TEXT,
  file_hash TEXT,
  file_size INTEGER,
  is_mandatory BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  published_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);''',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text('Jalankan SQL ini di SQL Editor di dashboard Supabase.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('TUTUP'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkVersionsTable(); // Coba periksa ulang setelah user membuat perubahan
            },
            child: Text('COBA LAGI'),
          ),
        ],
      ),
    );
  }

  // Generate SQL untuk menambahkan kolom yang hilang
  String _generateAlterTableSQL(List<String> missingColumns) {
    final sqlCommands = <String>[];

    for (final column in missingColumns) {
      String dataType;
      String defaultValue = '';

      switch (column) {
        case 'latest_version_name':
        case 'platform':
        case 'apk_download_url':
        case 'file_hash':
        case 'release_notes':
          dataType = 'TEXT';
          break;
        case 'latest_version_code':
        case 'file_size':
          dataType = 'INTEGER';
          break;
        case 'is_mandatory':
          dataType = 'BOOLEAN';
          defaultValue = ' DEFAULT false';
          break;
        case 'created_at':
        case 'published_at':
        case 'updated_at':
          dataType = 'TIMESTAMPTZ';
          defaultValue = ' DEFAULT NOW()';
          break;
        default:
          dataType = 'TEXT';
      }

      sqlCommands.add(
          'ALTER TABLE versions ADD COLUMN IF NOT EXISTS $column $dataType$defaultValue;');
    }

    return sqlCommands.join('\n');
  }
}
