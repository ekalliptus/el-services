import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'package:servicehponline/core/theme/app_colors.dart';
import 'package:servicehponline/features/maintenance/maintenance_service.dart';

class MaintenancePage extends StatefulWidget {
  final String title;
  final String message;
  final DateTime? estimatedCompletion;

  const MaintenancePage({
    Key? key,
    this.title = 'Aplikasi Sedang Maintenance',
    this.message =
        'Kami sedang melakukan perbaikan sistem untuk meningkatkan layanan. Silakan kembali lagi nanti.',
    this.estimatedCompletion,
  }) : super(key: key);

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  Timer? _maintenanceCheckTimer;
  bool _isChecking = false;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    // Inisialisasi data locale untuk bahasa Indonesia
    initializeDateFormatting('id_ID', null);

    // Mulai timer untuk memeriksa status maintenance secara otomatis setiap 30 detik
    _startMaintenanceCheckTimer();
  }

  @override
  void dispose() {
    _maintenanceCheckTimer?.cancel();
    super.dispose();
  }

  // Fungsi untuk memulai timer pengecekan maintenance
  void _startMaintenanceCheckTimer() {
    _maintenanceCheckTimer?.cancel();
    _maintenanceCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _checkMaintenanceStatus();
    });
  }

  // Memeriksa status maintenance
  Future<void> _checkMaintenanceStatus() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    try {
      final isInMaintenanceMode =
          await MaintenanceService.isInMaintenanceMode(forceCheck: true);

      if (!isInMaintenanceMode && mounted) {
        // Jika maintenance sudah tidak aktif, kembali ke halaman utama
        _returnToHomePage();
      }
    } catch (e) {
      print('Error saat memeriksa status maintenance: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  // Tombol "Coba Lagi" ditekan
  Future<void> _handleRetryButton() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
    });

    try {
      final isInMaintenanceMode =
          await MaintenanceService.isInMaintenanceMode(forceCheck: true);

      if (!isInMaintenanceMode && mounted) {
        // Jika maintenance sudah tidak aktif, kembali ke halaman utama
        _returnToHomePage();
      } else if (mounted) {
        // Maintenance masih aktif, refresh halaman untuk mendapatkan detail terbaru
        final details = await MaintenanceService.getMaintenanceDetails();

        if (mounted) {
          // Refresh halaman dengan data baru
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MaintenancePage(
                title: details['title'],
                message: details['message'],
                estimatedCompletion: details['estimatedCompletion'],
              ),
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Aplikasi masih dalam perbaikan. Silakan tunggu.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      print('Error saat memeriksa status maintenance: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Terjadi kesalahan saat memeriksa status. Silakan coba lagi.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  // Navigasi kembali ke halaman utama melalui root route agar alur auth
  // (AuthBloc + pengecekan onboarding/profil di main.dart) berjalan kembali
  // dan username yang benar dipakai — bukan hardcode 'User'.
  void _returnToHomePage() {
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Icon(
                  Icons.engineering_rounded,
                  size: 120,
                  color: AppColors.warning,
                ),
                SizedBox(height: 32),

                // Title
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),

                // Message
                Text(
                  widget.message,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),

                // Estimated completion time (if provided)
                if (widget.estimatedCompletion != null) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Estimasi Selesai:',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.primary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _formatDateTime(widget.estimatedCompletion!),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                ],

                // Auto check update
                Text(
                  'Otomatis memeriksa status setiap 30 detik',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),

                // Refresh button
                ElevatedButton.icon(
                  onPressed: _isRetrying ? null : _handleRetryButton,
                  icon: _isRetrying
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Icon(Icons.refresh),
                  label: Text(_isRetrying ? 'Memeriksa...' : 'Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    disabledBackgroundColor:
                        colorScheme.primary.withValues(alpha: 0.6),
                    disabledForegroundColor:
                        colorScheme.onPrimary.withValues(alpha: 0.7),
                  ),
                ),

                // Checking indicator
                if (_isChecking && !_isRetrying) ...[
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Memeriksa status...',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    // Format: "Senin, 7 April 2025, 14:30 WIB"
    final List<String> hari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    final List<String> bulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];

    final String namaHari = hari[dateTime.weekday - 1];
    final String namaBulan = bulan[dateTime.month - 1];

    return '$namaHari, ${dateTime.day} $namaBulan ${dateTime.year}, '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} WIB';
  }
}
