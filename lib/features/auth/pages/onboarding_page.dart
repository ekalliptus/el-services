import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicehponline/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:servicehponline/features/profile/pages/profile_setup_page.dart';
import 'package:servicehponline/features/user/widgets/request_service_flow_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({Key? key}) : super(key: key);

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _locationPermissionGranted = false;
  bool _showLocationRationale = false;
  bool _isPermanentlyDenied = false;
  bool _isCheckingUserStatus = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Periksa status user saat halaman dibuka
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    setState(() => _isCheckingUserStatus = true);

    try {
      // Periksa apakah user sudah login
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print("USER LOGIN TERDETEKSI: ${currentUser.uid}");
        print("DisplayName: ${currentUser.displayName}");
        print("Email: ${currentUser.email}");
        print("Firebase PhoneNumber: ${currentUser.phoneNumber}");
        print("PhotoURL: ${currentUser.photoURL}");

        // Inisialisasi klien Supabase
        final supabase = Supabase.instance.client;

        // Periksa apakah user sudah pernah onboarding sebelumnya
        final prefs = await SharedPreferences.getInstance();
        final hasCompletedOnboarding =
            prefs.getBool('has_completed_onboarding') ?? false;

        if (hasCompletedOnboarding) {
          // SELALU periksa profil di Supabase terlebih dahulu
          try {
            print("Mencari profil di Supabase untuk UID: ${currentUser.uid}");
            final profileData = await supabase
                .from('profiles')
                .select()
                .eq('id', currentUser.uid)
                .maybeSingle();

            if (profileData != null) {
              print('Profil ditemukan di Supabase:');
              print('fullname: ${profileData['fullname']}');
              print('phoneNumber: ${profileData['phoneNumber']}');
              print('whatsapp: ${profileData['whatsapp']}');
              print('address: ${profileData['address']}');

              // Cek kelengkapan profil berdasarkan data Supabase
              bool isProfileComplete = profileData['fullname'] != null &&
                  profileData['phoneNumber'] != null &&
                  profileData['address'] != null;

              // Debug log tambahan untuk memastikan pengecekan berfungsi
              print(
                  'Status kelengkapan profil (isProfileComplete): $isProfileComplete');
              print('Detail pengecekan:');
              print('fullname: ${profileData['fullname']}');
              print('phoneNumber: ${profileData['phoneNumber']}');
              print('address: ${profileData['address']}');

              // Update flag berdasarkan hasil pemeriksaan Supabase
              await prefs.setBool('profile_complete', isProfileComplete);

              if (isProfileComplete) {
                print(
                    'PROFIL LENGKAP berdasarkan data Supabase - mengarahkan ke halaman utama');
                // Navigasi ke halaman utama
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => RequestServiceFlow(
                        username: profileData['fullname'] ??
                            currentUser.displayName ??
                            'Pengguna',
                      ),
                    ),
                  );
                  return;
                }
              } else {
                print('PROFIL TIDAK LENGKAP berdasarkan data Supabase:');
                print('fullname ada: ${profileData['fullname'] != null}');
                print('phoneNumber ada: ${profileData['phoneNumber'] != null}');
                print('whatsapp ada: ${profileData['whatsapp'] != null}');
                print('address ada: ${profileData['address'] != null}');

                // Profil tidak lengkap, arahkan ke setup profil
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileSetupPage(isFirstTime: false),
                    ),
                  );
                  return;
                }
              }
            } else {
              print(
                  'PROFIL TIDAK DITEMUKAN di Supabase untuk UID: ${currentUser.uid}');
              // Reset flag saat profil tidak ditemukan
              await prefs.setBool('profile_complete', false);

              // Arahkan ke setup profil dengan flag isFirstTime = true
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => ProfileSetupPage(isFirstTime: true),
                  ),
                );
                return;
              }
            }
          } catch (e) {
            print('ERROR saat memeriksa profil di Supabase: $e');
          }
        } else {
          print('User belum menyelesaikan onboarding');
          // User belum pernah onboarding, lanjutkan dengan flow onboarding
        }
      } else {
        print('Tidak ada user yang login');
      }
    } catch (e) {
      print('Error pada _checkUserStatus: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingUserStatus = false);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
  }

  Future<void> _requestLocationPermission() async {
    setState(() => _showLocationRationale = false);

    LocationPermission permission = await Geolocator.checkPermission();

    // Jika izin sudah ditolak permanen sejak awal, tampilkan opsi lanjut
    // tanpa lokasi (jangan diam tanpa melakukan apa pun).
    if (permission == LocationPermission.deniedForever) {
      setState(() => _isPermanentlyDenied = true);
      return;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        // Izin ditolak
        setState(() => _showLocationRationale = true);
        return;
      } else if (permission == LocationPermission.deniedForever) {
        // Izin ditolak secara permanen
        setState(() => _isPermanentlyDenied = true);
        return;
      }
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      // Izin diberikan
      setState(() => _locationPermissionGranted = true);

      // Feedback haptic
      HapticFeedback.mediumImpact();

      // Tunggu sejenak untuk animasi
      await Future.delayed(Duration(milliseconds: 1000));

      // Tandai onboarding selesai
      await _markOnboardingComplete();

      if (!mounted) return;

      // Navigasi ke halaman pengaturan profil
      _navigateToProfileSetup();
    }
  }

  void _continueWithoutLocation() async {
    // Tandai onboarding selesai
    await _markOnboardingComplete();

    if (!mounted) return;

    // Navigasi ke halaman pengaturan profil
    _navigateToProfileSetup();
  }

  void _navigateToProfileSetup() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (context) => ProfileSetupPage(isFirstTime: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _isCheckingUserStatus
          ? Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 40),
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Center(
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.location_on,
                                    size: 60,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 40),
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Text(
                                "Selamat datang di ANRServices!",
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 16),
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Text(
                                "Izinkan akses lokasi untuk pengalaman lebih personal dan kemudahan layanan kami.",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 24),
                            if (_showLocationRationale)
                              _buildRationaleMessage(),
                            if (_isPermanentlyDenied)
                              _buildPermanentlyDeniedMessage(),
                            if (_locationPermissionGranted)
                              _buildSuccessMessage(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildBottomButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildRationaleMessage() {
    final colorScheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Mengapa butuh lokasi?",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              "Kami membutuhkan lokasi Anda untuk menemukan teknisi terdekat dan mempercepat layanan service.",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermanentlyDeniedMessage() {
    final colorScheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.location_disabled, color: colorScheme.error),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Izin lokasi ditolak",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              "Kamu perlu mengaktifkan izin lokasi melalui Pengaturan perangkat untuk menggunakan fitur lengkap aplikasi.",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await Geolocator.openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "BUKA PENGATURAN",
                style: GoogleFonts.poppins(
                  color: colorScheme.onError,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    final colorScheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Terima kasih!",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              "Sekarang kamu bisa temukan layanan terdekat dengan mudah.",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_locationPermissionGranted)
            ElevatedButton(
              onPressed: _requestLocationPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                minimumSize: Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "IZINKAN LOKASI",
                style: GoogleFonts.poppins(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          if (_showLocationRationale || _isPermanentlyDenied)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: TextButton(
                onPressed: _continueWithoutLocation,
                style: TextButton.styleFrom(
                  minimumSize: Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outline),
                  ),
                ),
                child: Text(
                  "LANJUTKAN TANPA LOKASI",
                  style: GoogleFonts.poppins(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
