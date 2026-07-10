// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:servicehponline/core/utils/extra.dart';
import 'package:servicehponline/features/user/widgets/page_indicator_widget.dart';
import 'package:servicehponline/data/models/device_problems.dart';
import 'package:servicehponline/features/user/widgets/service_card_widget.dart';
import 'package:servicehponline/data/models/device_data.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:servicehponline/data/models/service_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:servicehponline/features/profile/pages/profile_page.dart';
import 'package:servicehponline/features/auth/pages/login_page.dart';
import 'package:servicehponline/features/testimonial/pages/all_testimonials_page.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:servicehponline/core/services/authentication.dart';
import 'package:servicehponline/core/services/update_service.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:servicehponline/features/maintenance/maintenance_service.dart';
import 'package:servicehponline/features/maintenance/maintenance_page.dart';
import 'package:servicehponline/core/theme/app_colors.dart';

class HomePageOne extends StatefulWidget {
  final Function() nextPage;
  final Function() prevPage;
  final String username;
  final Function(String) onDeviceSelected;

  const HomePageOne({
    super.key,
    required this.nextPage,
    required this.prevPage,
    required this.username,
    required this.onDeviceSelected,
  });
  @override
  _HomePageOneState createState() => _HomePageOneState();
}

class _HomePageOneState extends State<HomePageOne>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final _supabase = Supabase.instance.client;
  final firebase_auth.User? currentUser =
      firebase_auth.FirebaseAuth.instance.currentUser;
  List<ServiceModel> _recentServices = [];
  // Future testimoni di-cache sekali agar tidak dibuat ulang tiap rebuild
  // (widget ini sering rebuild: timer maintenance 1 menit, event GPS, dll).
  late Future<List<Map<String, dynamic>>> _testimonialsFuture;
  bool _isLoadingHistory = false;
  String _active = "";
  String _currentAddress = "Memuat lokasi...";
  bool _isLoadingLocation = true;
  StreamSubscription<ServiceStatus>? _gpsStatusSubscription;
  BuildContext? _dialogContext;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  bool _isGpsEnabled = false;

  // Cache history data
  DateTime? _lastHistoryFetch;
  final Duration _cacheExpiry = Duration(minutes: 5); // Cache bertahan 5 menit

  // Info package aplikasi
  PackageInfo? _packageInfo;
  bool _isCheckingUpdate = false;

  // Timer untuk pengecekan maintenance mode secara berkala
  Timer? _maintenanceCheckTimer;
  bool _isCheckingMaintenance = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _testimonialsFuture = _fetchTestimonials();
    _loadRecentHistory();
    _setupAnimations();
    _setupGpsListener();
    _getCurrentLocation();

    // Muat info aplikasi dan periksa pembaruan
    _initPackageInfo();

    // Setup timer untuk memeriksa status maintenance setiap 1 menit
    _startMaintenanceCheckTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _gpsStatusSubscription?.cancel();
    _maintenanceCheckTimer?.cancel(); // Batalkan timer saat widget dihapus
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkGPSAndCloseDialog();
      _checkMaintenanceMode(); // Periksa maintenance mode saat aplikasi di-resume
    }
  }

  Future<void> _checkGPSAndCloseDialog() async {
    try {
      bool isEnabled = await Geolocator.isLocationServiceEnabled();
      if (mounted) {
        setState(() {
          _isGpsEnabled = isEnabled;
        });

        if (isEnabled) {
          if (_dialogContext != null) {
            Navigator.of(_dialogContext!).pop();
            _dialogContext = null;
          }
          _getCurrentLocation();
        }
      }
    } catch (e) {
      print('Error checking GPS status: $e');
    }
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  void _setupGpsListener() {
    _gpsStatusSubscription?.cancel(); // Batalkan subscription yang ada
    _gpsStatusSubscription = Geolocator.getServiceStatusStream().listen((
      ServiceStatus status,
    ) async {
      if (status == ServiceStatus.enabled) {
        await _checkGPSAndCloseDialog();
      } else if (status == ServiceStatus.disabled) {
        if (mounted) {
          setState(() {
            _isGpsEnabled = false;
            _currentAddress = 'Layanan lokasi tidak aktif';
          });
          _showGpsDialog();
        }
      }
    });
  }

  void _showGpsDialog() {
    if (!mounted || _dialogContext != null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        _dialogContext = dialogContext;
        return WillPopScope(
          onWillPop: () async {
            bool isEnabled = await Geolocator.isLocationServiceEnabled();
            if (isEnabled) {
              if (mounted) {
                setState(() => _isGpsEnabled = true);
                Navigator.of(dialogContext).pop();
                _dialogContext = null;
                _getCurrentLocation();
              }
              return false;
            }
            return true;
          },
          child: AlertDialog(
            title: Text(
              'GPS Tidak Aktif',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_off,
                    size: 64, color: Theme.of(context).colorScheme.error),
                SizedBox(height: 16),
                Text(
                  'Aplikasi membutuhkan akses lokasi untuk melanjutkan. Silakan aktifkan GPS pada perangkat Anda.',
                  style: GoogleFonts.poppins(),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: <Widget>[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'AKTIFKAN GPS',
                        style: GoogleFonts.poppins(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () async {
                        await Geolocator.openLocationSettings();
                        // Cek status GPS setelah kembali dari pengaturan
                        await _checkGPSAndCloseDialog();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // Reset _dialogContext ketika dialog ditutup
      _dialogContext = null;
    });
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 10) {
      return "Selamat Pagi";
    } else if (hour < 15) {
      return "Selamat Siang";
    } else if (hour < 21) {
      return "Selamat Sore";
    } else {
      return "Selamat Malam";
    }
  }

  void setActiveFunc(String key) {
    if (DeviceProblems.problems.containsKey(key) &&
        DeviceProblems.problems[key]?.isNotEmpty == true) {
      setState(() {
        _active = key;
      });
      widget.onDeviceSelected(key);
      widget.nextPage();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maaf, layanan untuk perangkat ini belum tersedia',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(10),
        ),
      );
    }
  }

  @override
  void deactivate() {
    _active = "";
    super.deactivate();
  }

  @override
  void didUpdateWidget(HomePageOne oldWidget) {
    super.didUpdateWidget(oldWidget);
    _active = "";
  }

  Future<void> _loadRecentHistory() async {
    if (mounted) {
      setState(() {
        _isLoadingHistory = true;
      });
    }

    try {
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _recentServices = [];
            _isLoadingHistory = false;
          });
        }
        return;
      }

      // Cek apakah data dalam cache masih valid
      final now = DateTime.now();
      if (_lastHistoryFetch != null &&
          _recentServices.isNotEmpty &&
          now.difference(_lastHistoryFetch!) < _cacheExpiry) {
        // Data masih valid, tidak perlu reload
        if (mounted) {
          setState(() {
            _isLoadingHistory = false;
          });
        }
        return;
      }

      // Ambil hanya kolom yang benar-benar diperlukan
      final response = await _supabase
          .from('services')
          .select(
            'id, service_cost, status, device, brand, model, problem, created_at',
          )
          .eq('user_id', currentUser!.uid)
          .order('created_at', ascending: false)
          .limit(3);

      if (mounted) {
        setState(() {
          _recentServices =
              response.map((data) => ServiceModel.fromJson(data)).toList();
          _isLoadingHistory = false;
          _lastHistoryFetch = now; // Update waktu terakhir fetch
        });
      }
    } catch (e) {
      print('Error loading history: $e');
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() => _isLoadingLocation = true);

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      setState(() {
        _isGpsEnabled = serviceEnabled;
        if (!serviceEnabled) {
          _currentAddress = 'Layanan lokasi tidak aktif';
        }
      });

      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        _showGpsDialog();
        return;
      }

      // Cek izin lokasi
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isGpsEnabled = false;
            _currentAddress = 'Izin lokasi ditolak';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isGpsEnabled = false;
          _currentAddress = 'Izin lokasi ditolak permanen';
          _isLoadingLocation = false;
        });
        return;
      }

      // Dapatkan posisi
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Dapatkan alamat dari koordinat
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress = '${place.subLocality}, ${place.locality}';
          _isLoadingLocation = false;
          _isGpsEnabled = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = 'Gagal mendapatkan lokasi';
          _isLoadingLocation = false;
          _isGpsEnabled = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      // Tampilkan loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Sedang keluar dari aplikasi...'),
              ],
            ),
          );
        },
      );

      // Gunakan service Authentication untuk logout
      final authService = Authentication();
      await authService.signOut();

      if (!mounted) return;

      // Tutup dialog loading
      Navigator.of(context).pop();

      // Ubah navigasi ke Home page
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Home()),
        (route) => false,
      );
    } catch (e) {
      print('Error during logout: $e');
      if (!mounted) return;

      // Tutup dialog loading jika masih terbuka
      try {
        Navigator.of(context).pop();
      } catch (e) {
        // Dialog mungkin sudah ditutup
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal keluar dari aplikasi: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // Ambil daftar testimoni. Dipanggil sekali di initState dan disimpan ke
  // _testimonialsFuture agar tidak dibuat ulang setiap rebuild.
  Future<List<Map<String, dynamic>>> _fetchTestimonials() async {
    return await _supabase
        .from('testimonials')
        .select()
        .order('created_at', ascending: false)
        .limit(5);
  }

  // Tambahkan fungsi _buildAvatar sebelum build
  Widget _buildAvatar(Map<String, dynamic> testimonial) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: testimonial['photo_url'] != null
            ? Colors.transparent
            : colorScheme.primary,
        border: Border.all(color: colorScheme.outline, width: 1),
      ),
      child: CircleAvatar(
        backgroundColor: testimonial['photo_url'] != null
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primary,
        backgroundImage: testimonial['photo_url'] != null
            ? NetworkImage(testimonial['photo_url'])
            : null,
        child: testimonial['photo_url'] == null
            ? Text(
                () {
                  final name = (testimonial['fullname'] as String?)?.trim();
                  return (name != null && name.isNotEmpty)
                      ? name[0].toUpperCase()
                      : '?';
                }(),
                style: GoogleFonts.poppins(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              )
            : null,
      ),
    );
  }

  // Fungsi untuk refresh semua data
  Future<void> _refreshAllData() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      // Force refresh dengan menghapus cache
      _lastHistoryFetch = null;

      // Refresh lokasi
      await _getCurrentLocation();
      // Refresh riwayat service
      await _loadRecentHistory();
      // Periksa status maintenance
      await _checkMaintenanceMode();
      // Data testimoni akan otomatis di-refresh karena menggunakan FutureBuilder
    } catch (e) {
      print('Error refreshing data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Menggunakan _isGpsEnabled untuk mengontrol status GPS
    bool isGpsActive = _isGpsEnabled;
    final colorScheme = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        await _showExitWarningDialog();
        return false;
      },
      child: Opacity(
        opacity: isGpsActive ? 1.0 : 0.5,
        child: Scaffold(
          backgroundColor: colorScheme.surface,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section dengan Location Button yang selalu bisa diakses
                Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                await _getCurrentLocation();
                                if (!mounted) return;
                                // Refresh semua data setelah mendapatkan lokasi baru
                                _refreshAllData();
                              },
                              child: Row(
                                children: [
                              Icon(
                                Icons.location_on,
                                size: 20,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _isLoadingLocation
                                      ? "Memuat lokasi..."
                                      : _currentAddress,
                                  style: GoogleFonts.poppins(
                                    color: colorScheme.onSurfaceVariant,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AbsorbPointer(
                            absorbing: !isGpsActive,
                            child: PopupMenuButton<String>(
                              offset: Offset(0, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.shadow
                                        .withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                  backgroundImage: currentUser?.photoURL != null
                                      ? NetworkImage(currentUser!.photoURL!)
                                      : AssetImage(AppImages.logo)
                                          as ImageProvider,
                                ),
                              ),
                              itemBuilder: (BuildContext context) => [
                                PopupMenuItem<String>(
                                  value: 'profile',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        color: colorScheme.onSurface,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Profil Saya',
                                        style: GoogleFonts.poppins(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'logout',
                                  child: Row(
                                    children: [
                                      Icon(Icons.logout,
                                          color: colorScheme.error),
                                      SizedBox(width: 12),
                                      Text(
                                        'Keluar',
                                        style: GoogleFonts.poppins(
                                          color: colorScheme.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                switch (value) {
                                  case 'profile':
                                    if (currentUser != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProfilePage(
                                            user: currentUser!,
                                          ),
                                        ),
                                      );
                                    }
                                    break;
                                  case 'logout':
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(
                                          'Konfirmasi',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        content: Text(
                                          'Apakah Anda yakin ingin keluar?',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(),
                                child: Text(
                                  'BATAL',
                                  style: GoogleFonts.poppins(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              _handleLogout();
                                            },
                                child: Text(
                                  'KELUAR',
                                  style: GoogleFonts.poppins(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        break;
                      }
                    },
                  ),
                          ),
                        ],
                      ),
                      SizedBox(height: 32),

                      // Konten yang diblokir
                      AbsorbPointer(
                        absorbing: !isGpsActive,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Greeting & Title
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                              Text(
                                "${_getGreeting()}, ${widget.username}",
                                style: GoogleFonts.poppins(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Pilih perangkat\nyang sedang bermasalah",
                                style: GoogleFonts.poppins(
                                  color: colorScheme.onSurface,
                                        fontSize: 24.0,
                                        fontWeight: FontWeight.bold,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                            PageIndicator(currentPage: 0, darkMode: false),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Device Grid Section yang diblokir
                Expanded(
                  child: AbsorbPointer(
                    absorbing: !isGpsActive,
                    child: RefreshIndicator(
                      key: _refreshIndicatorKey,
                      onRefresh: _refreshAllData,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: [
                              // Device Grid
                              Container(
                                height: MediaQuery.of(context).size.width *
                                    0.4, // Tinggi container disesuaikan dengan lebar layar
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ...DeviceData.devices[0]
                                        .map(
                                          (device) => Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 4.0,
                                              ),
                                              child: ServiceCard(
                                                device: device,
                                                active: _active,
                                                setActive: setActiveFunc,
                                                nextPage: widget.nextPage,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ],
                                ),
                              ),
                              SizedBox(height: 12),

                              // Recent History Section
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Riwayat Service Terakhir',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/history');
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size(50, 30),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Lihat Semua',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              if (_isLoadingHistory)
                                Center(child: CircularProgressIndicator())
                              else if (_recentServices.isEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Belum ada riwayat service',
                                      style: GoogleFonts.poppins(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Column(
                                  children: _recentServices.map((service) {
                                    return Container(
                                      margin: EdgeInsets.only(bottom: 12),
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(
                                          16,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.surface,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    12,
                                                  ),
                                                ),
                                                child: Icon(
                                                  service.device.contains(
                                                            'iphone',
                                                          )
                                                      ? Icons.phone_iphone
                                                      : Icons.phone_android,
                                                  color: colorScheme.primary,
                                                  size: 24,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      DeviceProblems
                                                          .formatDeviceName(
                                                        {
                                                          'device':
                                                              service.device,
                                                          'brand':
                                                              service.brand,
                                                          'model':
                                                              service.model,
                                                        },
                                                      ),
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 14,
                                                        color: colorScheme.onSurface,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      DeviceProblems
                                                          .getProblemName(
                                                        service.problem,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 13,
                                                        color: colorScheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                    SizedBox(height: 8),
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(
                                                          context,
                                                          service.status,
                                                          serviceCost: service
                                                                          .price !=
                                                                      null &&
                                                                  service.price !=
                                                                      '-'
                                                              ? service.price
                                                              : null,
                                                        ).withAlpha(26),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          20,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        _getStatusText(
                                                          service.status,
                                                          serviceCost: service
                                                                          .price !=
                                                                      null &&
                                                                  service.price !=
                                                                      '-'
                                                              ? service.price
                                                              : null,
                                                        ),
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              _getStatusColor(
                                                            context,
                                                            service.status,
                                                            serviceCost: service
                                                                            .price !=
                                                                        null &&
                                                                    service.price !=
                                                                        '-'
                                                                ? service.price
                                                                : null,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),

                              // Testimonial Section
                              SizedBox(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Testimoni',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AllTestimonialsPage(),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size(50, 30),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Lihat Semua',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: _testimonialsFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }

                                  if (snapshot.hasError) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Gagal memuat testimoni',
                                          style: GoogleFonts.poppins(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final testimonials = snapshot.data ?? [];

                                  if (testimonials.isEmpty) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Belum ada testimoni',
                                          style: GoogleFonts.poppins(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: BouncingScrollPhysics(),
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: testimonials.map((testimonial) {
                                        return Container(
                                          width: MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.85,
                                          margin: EdgeInsets.only(
                                            right: 12,
                                          ),
                                          padding: EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: colorScheme.surfaceContainerHighest,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: colorScheme.outline,
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  _buildAvatar(testimonial),
                                                  SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          testimonial[
                                                              'fullname'],
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 16,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        Text(
                                                          DeviceProblems
                                                              .formatDeviceName(
                                                            testimonial,
                                                          ),
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: Colors
                                                                .grey[600],
                                                            fontSize: 14,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 16),
                                              Wrap(
                                                spacing: 2,
                                                children: List.generate(
                                                  5,
                                                  (index) => Icon(
                                                    index <
                                                            (testimonial[
                                                                    'rating'] ??
                                                                0)
                                                        ? Icons.star
                                                        : Icons.star_border,
                                                    color: AppColors.warning,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 12),
                                              Text(
                                                (testimonial['content'] ?? '')
                                                    as String,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  height: 1.5,
                                                  color: colorScheme.onSurface,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 12),
                                              Builder(
                                                builder: (context) {
                                                  final ts = DateTime.tryParse(
                                                    testimonial['created_at']
                                                            ?.toString() ??
                                                        '',
                                                  );
                                                  if (ts == null) {
                                                    return const SizedBox
                                                        .shrink();
                                                  }
                                                  return Text(
                                                    DateFormat('dd MMMM yyyy')
                                                        .format(ts),
                                                    style: GoogleFonts.poppins(
                                                      color: colorScheme.onSurfaceVariant,
                                                      fontSize: 12,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showExitWarningDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Peringatan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Anda tidak dapat kembali ke halaman sebelumnya. Silahkan lanjutkan proses service atau tutup aplikasi.',
            style: GoogleFonts.poppins(),
          ),
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                    child: Text(
                      'KELUAR',
                      style: GoogleFonts.poppins(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                ),
                TextButton(
                    child: Text(
                      'TUTUP',
                      style: GoogleFonts.poppins(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _getStatusText(String? status, {dynamic serviceCost}) {
    if (status == null) return '';
    switch (status.toUpperCase()) {
      case 'PENDING':
        return serviceCost != null ? 'Menunggu Pembayaran' : 'Menunggu Admin';
      case 'PROCESSED':
        return 'Diproses';
      case 'COMPLETED':
        return 'Selesai';
      case 'PAID':
        return 'Sudah Dibayar';
      case 'EXPIRED':
        return 'Kadaluarsa';
      case 'COMPLAINED':
        return 'Dikomplain';
      default:
        return status;
    }
  }

  Color _getStatusColor(BuildContext context, String? status,
      {dynamic serviceCost}) {
    final colorScheme = Theme.of(context).colorScheme;
    if (status == null) return colorScheme.onSurfaceVariant;
    switch (status.toUpperCase()) {
      case 'PENDING':
        return serviceCost != null ? AppColors.warning : colorScheme.primary;
      case 'PROCESSED':
        return colorScheme.primary;
      case 'COMPLETED':
        return AppColors.success;
      case 'PAID':
        return AppColors.success;
      case 'EXPIRED':
        return colorScheme.error;
      case 'COMPLAINED':
        return colorScheme.error;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  // Inisialisasi package info
  Future<void> _initPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _packageInfo = info;
      });
      print('Versi aplikasi saat ini: ${info.version} (${info.buildNumber})');

      // Periksa pembaruan setelah info aplikasi dimuat
      _checkForAppUpdates();
    } catch (e) {
      print('Error mendapatkan info aplikasi: $e');
    }
  }

  // Fungsi untuk memeriksa pembaruan aplikasi dengan benar
  Future<void> _checkForAppUpdates() async {
    if (_isCheckingUpdate) return; // Hindari pemeriksaan berulang

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      // Dapatkan layanan pembaruan dari provider
      final updateService = Provider.of<UpdateService>(context, listen: false);

      // Periksa versi terbaru dari server
      final updateInfo = await updateService.checkAppVersion();

      if (updateInfo == null) {
        print(
            'Tidak ada pembaruan yang tersedia atau aplikasi sudah versi terbaru');
        return;
      }

      // Bandingkan dengan versi yang terinstal
      if (_packageInfo != null) {
        // Pastikan kita membandingkan versi dengan format yang benar
        final int currentVersionCode = int.parse(_packageInfo!.buildNumber);
        final int latestVersionCode = updateInfo['latest_version_code'];

        print(
            'Versi terinstal: $currentVersionCode, Versi server: $latestVersionCode');

        // Jika versi yang terinstal sama atau lebih baru dari yang di server, jangan tampilkan popup
        if (currentVersionCode >= latestVersionCode) {
          print('Aplikasi sudah menggunakan versi terbaru');
          return;
        }

        // Jika sampai di sini, berarti ada versi baru yang tersedia
        if (mounted) {
          // Jalankan di microtask agar tidak mengganggu proses rendering
          Future.microtask(() {
            // Tampilkan banner untuk pembaruan opsional, dialog untuk yang wajib
            final isMandatory = updateInfo['is_mandatory'] ?? false;

            if (isMandatory) {
              updateService.showUpdateDialog(context, updateInfo);
            } else {
              updateService.showUpdateBanner(context, updateInfo);
            }
          });
        }
      }
    } catch (e) {
      print('Error saat memeriksa pembaruan aplikasi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  // Fungsi untuk memulai timer pengecekan maintenance
  void _startMaintenanceCheckTimer() {
    _maintenanceCheckTimer?.cancel();
    _maintenanceCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _checkMaintenanceMode();
    });

    // Lakukan pengecekan segera
    _checkMaintenanceMode();
  }

  // Fungsi untuk memeriksa status maintenance
  Future<void> _checkMaintenanceMode() async {
    if (_isCheckingMaintenance || !mounted) return;

    setState(() {
      _isCheckingMaintenance = true;
    });

    try {
      final isInMaintenanceMode =
          await MaintenanceService.isInMaintenanceMode(forceCheck: true);

      if (isInMaintenanceMode && mounted) {
        // Jika dalam maintenance mode, ambil detail dan arahkan ke halaman maintenance
        final details = await MaintenanceService.getMaintenanceDetails();

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MaintenancePage(
                title: details['title'],
                message: details['message'],
                estimatedCompletion: details['estimatedCompletion'],
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error memeriksa status maintenance: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingMaintenance = false;
        });
      }
    }
  }
}
