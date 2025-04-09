import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:servicehponline/core/services/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart'; // Untuk verifikasi hash
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  final Dio _dio = Dio();

  // Periksa pembaruan aplikasi terakhir kali dijalankan
  Future<bool> shouldCheckForUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final lastChecked = prefs.getInt('last_update_check') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Periksa apakah ada update yang tertunda (belum diinstal)
    final String? pendingUpdate = prefs.getString('latest_version_available');
    final bool updateDismissed = prefs.getBool('update_dismissed') ?? false;

    // Jika ada update yang tertunda dan belum diinstal, selalu kembalikan true
    // kecuali jika update telah ditolak dan belum melewati interval pemeriksaan
    if (pendingUpdate != null) {
      if (updateDismissed) {
        // Jika ditolak, tetap periksa setelah interval yang lebih pendek (2 jam)
        if (now - lastChecked > 2 * 60 * 60 * 1000) {
          return true;
        }
      } else {
        // Jika belum ditolak, selalu periksa
        return true;
      }
    }

    // Periksa setiap 6 jam, lebih agresif dari sebelumnya (24 jam)
    if (now - lastChecked > 6 * 60 * 60 * 1000) {
      return true;
    }

    // Selalu periksa pembaruan wajib setiap kali aplikasi dibuka
    final skipMandatoryCheck = prefs.getBool('skip_mandatory_check') ?? false;
    if (!skipMandatoryCheck) {
      return true;
    }

    return false;
  }

  // Memeriksa versi aplikasi terbaru dari Supabase
  Future<Map<String, dynamic>?> checkAppVersion() async {
    try {
      // Dapatkan info versi terinstal
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final int currentVersionCode = int.parse(packageInfo.buildNumber);

      print('Memeriksa pembaruan: Versi saat ini $currentVersionCode');

      // Dapatkan info versi terbaru dari Supabase
      final response = await SupabaseConfig.client
          .from('versions')
          .select()
          .eq('platform', 'android')
          .order('latest_version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        print('Tidak ada data versi di Supabase');
        return null;
      }

      final int latestVersionCode = response['latest_version_code'];

      print('Versi terbaru di server: $latestVersionCode');

      // Jika versi baru tersedia
      if (latestVersionCode > currentVersionCode) {
        return {
          'current_version': currentVersionCode,
          'latest_version_code': latestVersionCode,
          'latest_version_name': response['latest_version_name'],
          'apk_url': response['apk_download_url'],
          'release_notes': response['release_notes'] ?? '',
          'is_mandatory': response['is_mandatory'] ?? false,
          'file_hash': response['file_hash'], // Hash untuk verifikasi
          'file_size': response['file_size'], // Ukuran file
        };
      } else {
        print('Aplikasi sudah versi terbaru');
        return null; // Tidak ada pembaruan yang tersedia
      }
    } catch (e) {
      print('Error saat memeriksa versi aplikasi: $e');
      return null;
    }
  }

  // Variabel untuk melacak apakah dialog update sudah ditampilkan pada sesi ini
  bool _updateDialogShownInSession = false;

  // Fungsi untuk menampilkan notifikasi update yang optimal
  Future<void> showOptimalUpdateNotification(
      BuildContext context, Map<String, dynamic>? updateInfo) async {
    if (updateInfo == null) return;

    // Hindari menampilkan dialog update dua kali dalam satu sesi
    if (_updateDialogShownInSession) {
      print('Dialog update sudah ditampilkan dalam sesi ini. Diabaikan.');
      return;
    }

    _updateDialogShownInSession = true;

    final bool isMandatory = updateInfo['is_mandatory'] ?? false;

    // Simpan referensi untuk update yang tersedia
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'latest_version_available', updateInfo['latest_version_name']);
    // Hapus flag update_dismissed saat memulai
    await prefs.setBool('update_dismissed', false);

    // Jika update wajib, tampilkan dialog full-screen
    if (isMandatory) {
      showUpdateDialog(context, updateInfo);
    } else {
      // Untuk update opsional, tampilkan banner terlebih dahulu
      showUpdateBanner(context, updateInfo);

      // Simpan info bahwa banner sudah ditampilkan
      await prefs.setBool('update_banner_shown', true);
    }

    // Setel waktu terakhir pemberitahuan
    await prefs.setInt(
        'last_update_notification', DateTime.now().millisecondsSinceEpoch);
  }

  // Menampilkan dialog pembaruan kepada pengguna
  void showUpdateDialog(BuildContext context, Map<String, dynamic> updateInfo) {
    final bool isMandatory = updateInfo['is_mandatory'] ?? false;
    final String versionName = updateInfo['latest_version_name'];
    final String releaseNotes = updateInfo['release_notes'] ?? '';
    final String apkUrl = updateInfo['apk_url'];
    final int? fileSize =
        updateInfo['file_size']; // Ukuran file untuk ditampilkan

    // Dialog dengan desain yang lebih menarik
    showGeneralDialog(
      context: context,
      barrierDismissible:
          !isMandatory, // Tidak bisa ditutup jika pembaruan wajib
      barrierLabel: 'Pembaruan',
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return PopScope(
          canPop: !isMandatory,
          child: Center(
            child: Container(
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.zero,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header dengan ikon dan warna latar belakang
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            isMandatory
                                ? Icons.system_update_alt
                                : Icons.system_update,
                            color: Colors.white,
                            size: 48,
                          ),
                          SizedBox(height: 8),
                          Text(
                            isMandatory
                                ? 'Pembaruan Wajib'
                                : 'Pembaruan Tersedia',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content area
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Versi informasi
                          Row(
                            children: [
                              Icon(Icons.new_releases, color: Colors.amber),
                              SizedBox(width: 8),
                              Text(
                                'Versi $versionName',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          // Ukuran file
                          if (fileSize != null)
                            Row(
                              children: [
                                Icon(Icons.file_download, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  'Ukuran: ${_formatFileSize(fileSize)}',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          SizedBox(height: 16),
                          // Release notes
                          if (releaseNotes.isNotEmpty) ...[
                            Text(
                              'Fitur & Perbaikan:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.all(12),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                releaseNotes,
                                style: TextStyle(height: 1.3),
                              ),
                            ),
                          ],
                          SizedBox(height: 16),
                          // Notifikasi jika wajib
                          if (isMandatory)
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Colors.red),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Pembaruan ini wajib untuk melanjutkan menggunakan aplikasi.',
                                      style: TextStyle(
                                        color: Colors.red.shade900,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Buttons
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _downloadAndInstallApk(
                                  context, apkUrl, updateInfo['file_hash']);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Perbarui Sekarang',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!isMandatory) ...[
                            SizedBox(height: 8),
                            TextButton(
                              onPressed: () async {
                                // Tandai bahwa update ditolak untuk sementara
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool('update_dismissed', true);
                                // Tetap catat waktu pengecekan untuk perhitungan interval
                                await prefs.setInt('last_update_check',
                                    DateTime.now().millisecondsSinceEpoch);
                                Navigator.of(context).pop();

                                // Set timer untuk menampilkan lagi dialog setelah beberapa waktu
                                Future.delayed(Duration(minutes: 30), () {
                                  if (_updateDialogShownInSession) {
                                    _updateDialogShownInSession =
                                        false; // Reset flag
                                  }
                                });
                              },
                              child: Text('Nanti'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: child,
        );
      },
    );
  }

  // Dialog global yang dapat diakses di seluruh kelas
  BuildContext? _dialogContext;
  bool _isDialogShowing = false;

  // Menampilkan dialog unduhan sebagai dialog global
  void showDownloadDialog(BuildContext context) {
    if (_isDialogShowing) return;

    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        _dialogContext = dialogContext;
        return _buildDownloadDialog(0, 0, 0);
      },
    );
  }

  // Update progress dialog
  void updateDownloadProgress(
      BuildContext context, int progress, int received, int total) {
    if (!_isDialogShowing || _dialogContext == null) return;

    try {
      // Update widget secara langsung melalui StatefulBuilder tanpa menutup dialog
      Navigator.of(_dialogContext!).pop(); // Tutup dialog sebelumnya

      // Buka dialog baru dengan informasi baru
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          _dialogContext = dialogContext;
          return _buildDownloadDialog(progress, received, total);
        },
      );
    } catch (e) {
      print('Error saat update dialog progress: $e');
    }
  }

  // Tutup dialog dengan benar
  void closeDownloadDialog(BuildContext context) {
    if (!_isDialogShowing || _dialogContext == null) return;

    try {
      Navigator.of(_dialogContext!).pop();
      _dialogContext = null;
      _isDialogShowing = false;
    } catch (e) {
      print('Error saat menutup dialog dengan _dialogContext: $e');
      try {
        Navigator.of(context, rootNavigator: true).pop();
        _dialogContext = null;
        _isDialogShowing = false;
      } catch (e2) {
        print('Gagal semua cara menutup dialog: $e2');
      }
    }
  }

  // Builder untuk dialog unduhan
  Widget _buildDownloadDialog(int progress, int receivedBytes, int totalBytes) {
    String downloadedSize = _formatFileSize(receivedBytes);
    String totalSize = totalBytes > 0 ? _formatFileSize(totalBytes) : '?';

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.system_update_alt, color: Colors.blue, size: 20),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Mengunduh Pembaruan',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info unduhan dengan ukuran
          Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                totalBytes > 0
                    ? Text(
                        '$downloadedSize / $totalSize',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      )
                    : Text(
                        'Menghitung ukuran...',
                        style: TextStyle(fontSize: 14),
                      ),
                if (progress > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$progress%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Linear progress bar
          LinearProgressIndicator(
            value: progress > 0 ? progress / 100 : null,
            minHeight: 10,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),

          SizedBox(height: 16),

          // Info file
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.android, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'APK Aplikasi',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Status:',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _getDownloadStatus(progress),
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),

                // Tambahkan kecepatan unduhan jika sedang mengunduh
                if (progress > 0 && progress < 100)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Kecepatan:',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[700]),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Sedang dihitung...',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Pesan info
          SizedBox(height: 16),
          Text(
            'Mohon jangan tutup dialog ini atau keluar dari aplikasi selama proses pengunduhan. Instalasi akan dimulai secara otomatis setelah unduhan selesai.',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        if (progress <= 0)
          TextButton(
            onPressed: () {
              Navigator.of(_dialogContext!).pop();
              _dialogContext = null;
              _isDialogShowing = false;

              // Reset flag agar dialog update dapat muncul kembali
              _updateDialogShownInSession = false;

              // Jadwalkan penampilan dialog update lagi setelah beberapa waktu
              Future.delayed(Duration(minutes: 5), () {
                // Cek kembali update yang tersedia
                checkAppVersion().then((updateInfo) {
                  if (updateInfo != null) {
                    // Jika konteks masih valid, tampilkan dialog lagi
                    BuildContext? contextFromApp = _getActiveContext();
                    if (contextFromApp != null) {
                      showUpdateDialog(contextFromApp, updateInfo);
                    }
                  }
                });
              });
            },
            child: Text('BATALKAN'),
          ),
      ],
    );
  }

  // Mengunduh dan menginstal file APK
  Future<void> _downloadAndInstallApk(
      BuildContext context, String apkUrl, String? expectedHash) async {
    // Simpan context yang stabil untuk digunakan setelah operasi async
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars();

    // Track if dialog is shown
    bool isDialogOpen = true;
    String? savedPath;
    bool downloadCompleted = false;

    // Variabel untuk menampilkan informasi download
    int totalBytes = 0;
    int receivedBytes = 0;

    try {
      // Tampilkan dialog progress awal
      showDownloadDialog(context);

      // Dapatkan direktori penyimpanan sementara
      final Directory tempDir = await getTemporaryDirectory();
      final String savePath = '${tempDir.path}/servicehponline-update.apk';
      savedPath = savePath;

      // Hapus file lama jika ada
      final file = File(savePath);
      if (await file.exists()) {
        try {
          await file.delete();
          print('File lama dihapus: $savePath');
        } catch (e) {
          print('Gagal menghapus file lama: $e');
        }
      }

      // Unduh file APK dengan progress
      await _dio.download(
        apkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          receivedBytes = received;
          totalBytes = total;

          if (total != -1 && isDialogOpen) {
            try {
              int progress = (received / total * 100).toInt();

              // Update progress di dialog progress
              try {
                updateDownloadProgress(
                    context, progress, receivedBytes, totalBytes);
              } catch (dialogError) {
                print('Dialog error saat update: $dialogError');
                // Tidak perlu set isDialogOpen = false di sini
              }

              // Tandai ketika download 100% selesai
              if (progress >= 100) {
                downloadCompleted = true;
                print('Download 100% selesai');
              }
            } catch (e) {
              print('Error saat memperbarui dialog: $e');
            }
          }
        },
      );

      // Tambahan: log untuk debugging
      print('Status download selesai: $downloadCompleted');

      // Tambahkan delay singkat untuk memastikan file selesai ditulis
      await Future.delayed(
          Duration(milliseconds: downloadCompleted ? 1000 : 500));

      // PENTING: Tutup dialog progress dengan benar
      // Dibuat penghalang try-catch khusus untuk memastikan dialog ditutup
      try {
        closeDownloadDialog(context);
        isDialogOpen = false;
        print('Dialog ditutup dengan sukses');
      } catch (closeError) {
        print('Error saat menutup dialog utama: $closeError');
        // Coba cara kedua untuk menutup dialog
        try {
          Navigator.of(context, rootNavigator: true).pop();
          isDialogOpen = false;
          print('Dialog ditutup dengan cara alternatif');
        } catch (e) {
          print('Gagal menutup dialog dengan semua cara: $e');
        }
      }

      // Verifikasi file APK sebelum menginstal
      final bool isValidApk =
          await _verifyDownloadedApk(savePath, expectedHash);
      if (!isValidApk) {
        if (scaffoldMessenger.mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content:
                  Text('File yang diunduh tidak valid. Silakan coba lagi.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
              action: SnackBarAction(
                label: 'COBA LAGI',
                onPressed: () {
                  // Coba download ulang
                  _downloadAndInstallApk(context, apkUrl, expectedHash);
                },
              ),
            ),
          );
        }
        return;
      }

      // Tampilkan snackbar bahwa unduhan selesai
      if (scaffoldMessenger.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Unduhan selesai. Memulai instalasi...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Gunakan Future.delayed untuk memberi waktu OS memproses file
      await Future.delayed(Duration(seconds: 1));

      // Buka file APK untuk instalasi
      await _openApkDirectly(savedPath);

      // Jika instalasi gagal, coba cara alternatif
      try {
        // Tunggu 3 detik untuk melihat apakah instalasi dimulai
        await Future.delayed(Duration(seconds: 3));
        // Coba lagi dengan cara alternatif
        await _openAndroidApkWithIntent(savedPath);
      } catch (e) {
        print('Metode alternatif juga gagal: $e');
      }
    } catch (e) {
      print('Error saat mengunduh atau menginstal APK: $e');

      // Pastikan dialog ditutup jika masih terbuka
      if (isDialogOpen) {
        try {
          closeDownloadDialog(context);
          isDialogOpen = false;
        } catch (dialogError) {
          print('Error saat menutup dialog: $dialogError');
          try {
            Navigator.of(context, rootNavigator: true).pop();
          } catch (_) {}
        }
      }

      // Tampilkan error secara aman
      if (scaffoldMessenger.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
                'Gagal mengunduh atau menginstal pembaruan. Silakan coba lagi.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'DETAIL',
              onPressed: () {
                // Tampilkan detail error jika konteks masih valid
                if (Navigator.of(context).mounted) {
                  _showErrorDialogSafe(context, 'Gagal: $e', savedPath);
                }
              },
            ),
          ),
        );
      }
    }
  }

  // Menampilkan dialog error yang aman setelah operasi async
  void _showErrorDialogSafe(
      BuildContext context, String message, String? filePath) {
    // Cek apakah konteks masih valid
    if (!Navigator.of(context).mounted) {
      print('Konteks tidak valid untuk menampilkan dialog error');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Terjadi Kesalahan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              if (filePath != null) ...[
                SizedBox(height: 16),
                Text(
                    'Anda dapat mencoba menginstal file secara manual atau batalkan.'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('TUTUP'),
            ),
            if (filePath != null)
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  // Gunakan metode yang aman untuk membuka APK
                  try {
                    await _openApkWithPermissionHandling(context, filePath);
                  } catch (e) {
                    print('Gagal membuka APK: $e');
                  }
                },
                child: Text('COBA LAGI'),
              ),
          ],
        );
      },
    );
  }

  // Metode baru untuk menangani pembukaan APK dengan penanganan izin
  Future<void> _openApkWithPermissionHandling(
      BuildContext context, String filePath) async {
    // Periksa apakah konteks masih valid
    bool isContextValid = context.mounted;

    try {
      // Pastikan file ada dan dapat dibaca
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File tidak ditemukan: $filePath');
      }

      final fileSize = await file.length();
      print('Ukuran file APK: ${_formatFileSize(fileSize)}');

      if (fileSize <= 1024) {
        // Jika file kurang dari 1KB, kemungkinan corrupted
        throw Exception('File APK invalid - ukuran terlalu kecil');
      }

      // Coba buka file
      print('Membuka file APK: $filePath');
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      // Analisis hasil
      print('Hasil OpenFilex: ${result.type} - ${result.message}');

      if (result.type != ResultType.done) {
        print('Error membuka file: ${result.type} - ${result.message}');

        // Coba pendekatan alternatif jika mengalami masalah
        if (Platform.isAndroid) {
          // Secara eksplisit gunakan intent pada Android tanpa ketergantungan pada context
          await _openAndroidApkWithIntent(filePath);
        } else if (isContextValid) {
          // Hanya gunakan dialog jika konteks masih valid
          if (context.mounted) {
            if (result.message.toLowerCase().contains('permission') ||
                result.message.toLowerCase().contains('izin')) {
              // Menampilkan dialog panduan untuk pengguna mengaktifkan izin
              _showInstallPermissionGuide(context, filePath);
            } else {
              // Menampilkan dialog error umum
              _showErrorDialogSafe(context,
                  'Gagal membuka file instalasi: ${result.message}', filePath);
            }
          }
        } else {
          print('Konteks tidak valid untuk menampilkan dialog izin/error');
        }
      }
    } catch (e) {
      print('Exception saat membuka APK: $e');

      // Hanya tampilkan dialog jika konteks masih valid
      if (isContextValid && context.mounted) {
        _showErrorDialogSafe(
            context, 'Terjadi kesalahan saat mencoba menginstal: $e', filePath);
      } else {
        print('Konteks tidak valid untuk menampilkan dialog error');
      }
    }
  }

  // Dialog panduan untuk mendapatkan izin instalasi
  void _showInstallPermissionGuide(BuildContext context, String filePath) {
    // Cek apakah konteks masih valid
    if (!context.mounted) {
      print('Konteks tidak valid untuk panduan izin instalasi');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Izin Diperlukan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Aplikasi ini memerlukan izin untuk menginstal aplikasi dari sumber tidak dikenal. Ikuti langkah berikut:'),
              SizedBox(height: 16),
              Text('1. Buka Pengaturan'),
              Text('2. Ketuk Keamanan atau Privasi'),
              Text(
                  '3. Aktifkan "Instal dari sumber tidak dikenal" atau "Instal Aplikasi Tidak Dikenal"'),
              Text('4. Kembali dan coba lagi'),
              SizedBox(height: 16),
              Text('Atau unduh dan instal pembaruan secara manual:'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('TUTUP'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _openInstallSettings();
              },
              child: Text('BUKA PENGATURAN'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await _openApkDirectly(filePath);
                } catch (e) {
                  print('Gagal membuka APK langsung: $e');
                }
              },
              child: Text('COBA LAGI'),
            ),
          ],
        );
      },
    );
  }

  // Metode untuk membuka APK langsung tanpa penanganan konteks
  Future<void> _openApkDirectly(String filePath) async {
    try {
      await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );
    } catch (e) {
      print('Error saat membuka APK langsung: $e');
      await _openAndroidApkWithIntent(filePath);
    }
  }

  // Tambahan: metode untuk membuka APK di Android menggunakan Intent
  Future<void> _openAndroidApkWithIntent(String filePath) async {
    try {
      final file = File(filePath);
      final Uri uri = Uri.file(file.path);

      // Coba menggunakan URL Launcher sebagai alternatif
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        print('Mencoba instalasi dengan URL Launcher: $uri');
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        print('Tidak dapat membuka URI: $uri');
        throw Exception('Tidak dapat membuka file APK dengan URL Launcher');
      }
    } catch (e) {
      print('Error saat mencoba metode alternatif instalasi: $e');
      rethrow;
    }
  }

  // Verifikasi file APK yang diunduh
  Future<bool> _verifyDownloadedApk(
      String filePath, String? expectedHash) async {
    try {
      // Pastikan file ada
      final file = File(filePath);
      if (!await file.exists()) {
        print('File tidak ditemukan: $filePath');
        return false;
      }

      // Periksa ukuran file
      final fileSize = await file.length();
      if (fileSize <= 0) {
        print('File kosong');
        return false;
      }

      // Verifikasi file adalah APK
      final bytes = await file.openRead(0, 50).toList();
      if (bytes.isEmpty) {
        print('Tidak dapat membaca file');
        return false;
      }

      // APK adalah file ZIP, jadi seharusnya dimulai dengan PK magic numbers
      final List<int> flatBytes = bytes.expand((x) => x).toList();
      if (flatBytes.length < 4 ||
          flatBytes[0] != 0x50 || // P
          flatBytes[1] != 0x4B || // K
          flatBytes[2] != 0x03 || // Control Z
          flatBytes[3] != 0x04) {
        // EOT
        print('Format file tidak valid (bukan APK/ZIP)');
        return false;
      }

      // Periksa hash jika disediakan
      if (expectedHash != null && expectedHash.isNotEmpty) {
        final bytes = await file.readAsBytes();
        final digest = sha256.convert(bytes);
        final fileHash = digest.toString();

        if (fileHash != expectedHash) {
          print(
              'Hash tidak cocok. Diharapkan: $expectedHash, Diperoleh: $fileHash');
          return false;
        }
        print('Verifikasi hash berhasil');
      }

      return true;
    } catch (e) {
      print('Error saat memverifikasi APK: $e');
      return false;
    }
  }

  // Membuka pengaturan instalasi aplikasi untuk Android
  Future<void> _openInstallSettings() async {
    try {
      // Gunakan cara sederhana: buka pengaturan keamanan umum
      final result = await OpenFilex.open(
        'package:com.android.settings',
        type: 'application/android.settings',
      );

      if (result.type != ResultType.done) {
        print('Gagal membuka pengaturan: ${result.message}');
      }
    } catch (e) {
      print('Error saat membuka pengaturan instalasi: $e');
    }
  }

  // Helper untuk status unduhan
  String _getDownloadStatus(int progress) {
    if (progress <= 0) {
      return 'Menyiapkan unduhan...';
    } else if (progress < 20) {
      return 'Memulai unduhan...';
    } else if (progress < 90) {
      return 'Mengunduh...';
    } else if (progress < 100) {
      return 'Hampir selesai...';
    } else {
      return 'Selesai, memverifikasi file...';
    }
  }

  // Format ukuran file ke format yang lebih mudah dibaca
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Menampilkan banner notifikasi update di bagian atas aplikasi
  void showUpdateBanner(BuildContext context, Map<String, dynamic> updateInfo) {
    final bool isMandatory = updateInfo['is_mandatory'] ?? false;
    final String versionName = updateInfo['latest_version_name'];

    // Pastikan banner hanya muncul sekali
    final OverlayState? overlayState = Overlay.of(context);
    if (overlayState == null) return;

    // Buat overlay entry
    late final OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10, // Di bawah status bar
        left: 16,
        right: 16,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: isMandatory ? Colors.red.shade600 : Colors.blue.shade600,
          child: InkWell(
            onTap: () {
              // Hapus banner ketika diklik
              overlayEntry.remove();
              // Tampilkan dialog update
              showUpdateDialog(context, updateInfo);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    isMandatory
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline,
                    color: Colors.white,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isMandatory
                              ? 'Pembaruan Wajib Tersedia'
                              : 'Pembaruan Tersedia',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Versi terbaru ($versionName) telah siap diunduh',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withAlpha(230),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Tampilkan overlay
    overlayState.insert(overlayEntry);

    // Hapus overlay setelah 7 detik untuk peringatan non-wajib
    if (!isMandatory) {
      Future.delayed(Duration(seconds: 7), () {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
      });
    }
  }

  // Fungsi untuk mendapatkan context aktif dari aplikasi
  // Ini hanya placeholder, implementasikan dengan provider/inherited widget di aplikasi utama
  BuildContext? _getActiveContext() {
    // Di implementasi sebenarnya, gunakan navigator key global atau provider
    return null;
  }
}
