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
  bool _isLoadingHistory = false;
  String _active = "";
  String _currentAddress = "Memuat lokasi...";
  bool _isLoadingLocation = true;
  bool _isGpsEnabled = false;
  StreamSubscription<ServiceStatus>? _gpsStatusSubscription;
  BuildContext? _dialogContext;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecentHistory();
    _setupAnimations();
    _setupGpsListener();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _gpsStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkGPSAndCloseDialog();
    }
  }

  Future<void> _checkGPSAndCloseDialog() async {
    bool isEnabled = await Geolocator.isLocationServiceEnabled();
    if (isEnabled && mounted && _dialogContext != null) {
      Navigator.of(_dialogContext!).pop();
      _dialogContext = null;
      _getCurrentLocation();
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
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  void _setupGpsListener() {
    _gpsStatusSubscription = Geolocator.getServiceStatusStream().listen(
      (ServiceStatus status) {
        if (status == ServiceStatus.enabled) {
          _getCurrentLocation();
        } else if (status == ServiceStatus.disabled) {
          setState(() {
            _currentAddress = 'Layanan lokasi tidak aktif';
          });
          _getCurrentLocation();
        }
      },
    );
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
          backgroundColor: Colors.red,
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
        setState(() {
          _recentServices = [];
          _isLoadingHistory = false;
        });
        return;
      }

      final response = await _supabase
          .from('services')
          .select('*, status')
          .eq('user_id', currentUser!.uid)
          .order('created_at', ascending: false)
          .limit(3);

      if (mounted) {
        setState(() {
          _recentServices =
              response.map((data) => ServiceModel.fromJson(data)).toList();
          _isLoadingHistory = false;
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
      // Cek apakah layanan lokasi diaktifkan
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      setState(() => _isGpsEnabled = serviceEnabled);

      if (!serviceEnabled) {
        setState(() {
          _currentAddress = 'Layanan lokasi tidak aktif';
          _isLoadingLocation = false;
        });

        // Tampilkan dialog untuk mengaktifkan GPS
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return WillPopScope(
              onWillPop: () async {
                // Cek status GPS saat tombol back ditekan
                bool isEnabled = await Geolocator.isLocationServiceEnabled();
                if (isEnabled) {
                  Navigator.of(dialogContext).pop();
                  _getCurrentLocation();
                  return false;
                }
                return true;
              },
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  // Setup listener untuk status GPS
                  Geolocator.getServiceStatusStream()
                      .listen((ServiceStatus status) {
                    if (status == ServiceStatus.enabled && mounted) {
                      setDialogState(() {
                        _isGpsEnabled = true;
                      });
                    } else {
                      setDialogState(() {
                        _isGpsEnabled = false;
                      });
                    }
                  });

                  return AlertDialog(
                    title: Text(
                      'GPS Tidak Aktif',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 64,
                          color: Colors.red,
                        ),
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
                                backgroundColor: Colors.blue,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'AKTIFKAN GPS',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () async {
                                await Geolocator.openLocationSettings();
                                // Cek status GPS setelah kembali dari pengaturan
                                bool isEnabled =
                                    await Geolocator.isLocationServiceEnabled();
                                if (isEnabled && mounted) {
                                  setDialogState(() {
                                    _isGpsEnabled = true;
                                  });
                                }
                              },
                            ),
                          ),
                          SizedBox(width: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                            ),
                            child: Text(
                              'TUTUP',
                              style: GoogleFonts.poppins(
                                color:
                                    _isGpsEnabled ? Colors.blue : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _isGpsEnabled
                                ? () {
                                    Navigator.of(dialogContext).pop();
                                    _getCurrentLocation();
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
        return;
      }

      // Cek izin lokasi
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _currentAddress = 'Izin lokasi ditolak';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = 'Gagal mendapatkan lokasi';
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await firebase_auth.FirebaseAuth.instance.signOut();
      if (!mounted) return;

      // Ubah navigasi ke Home page
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const Home(),
        ),
        (route) => false,
      );
    } catch (e) {
      print('Error during logout: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal keluar dari aplikasi'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Tambahkan fungsi _buildAvatar sebelum build
  Widget _buildAvatar(Map<String, dynamic> testimonial) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            testimonial['photo_url'] != null ? Colors.transparent : Colors.blue,
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: CircleAvatar(
        backgroundColor:
            testimonial['photo_url'] != null ? Colors.grey[200] : Colors.blue,
        backgroundImage: testimonial['photo_url'] != null
            ? NetworkImage(testimonial['photo_url'])
            : null,
        child: testimonial['photo_url'] == null
            ? Text(
                testimonial['fullname'][0].toUpperCase(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
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
      // Refresh lokasi
      await _getCurrentLocation();
      // Refresh riwayat service
      await _loadRecentHistory();
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
    bool isGpsActive = _currentAddress != 'Layanan lokasi tidak aktif';

    return WillPopScope(
      onWillPop: () async {
        await _showExitWarningDialog();
        return false;
      },
      child: Opacity(
        opacity: isGpsActive ? 1.0 : 0.5,
        child: Scaffold(
          backgroundColor: Colors.white,
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
                                // Refresh semua data setelah mendapatkan lokasi baru
                                _refreshAllData();
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 20,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _isLoadingLocation
                                          ? "Memuat lokasi..."
                                          : _currentAddress,
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey[600],
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
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.grey[100],
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
                                      Icon(Icons.person_outline,
                                          color: Colors.grey[700]),
                                      SizedBox(width: 12),
                                      Text(
                                        'Profil Saya',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'logout',
                                  child: Row(
                                    children: [
                                      Icon(Icons.logout, color: Colors.red),
                                      SizedBox(width: 12),
                                      Text(
                                        'Keluar',
                                        style: GoogleFonts.poppins(
                                          color: Colors.red,
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
                                          builder: (context) =>
                                              ProfilePage(user: currentUser!),
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
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: Text(
                                              'BATAL',
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey,
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
                                                color: Colors.red,
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
                                        color: Colors.grey[600],
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Pilih perangkat\nyang sedang bermasalah",
                                      style: GoogleFonts.poppins(
                                        color: Colors.black87,
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
                                        .map((device) => Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4.0),
                                                child: ServiceCard(
                                                  device: device,
                                                  active: _active,
                                                  setActive: setActiveFunc,
                                                  nextPage: widget.nextPage,
                                                ),
                                              ),
                                            ))
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
                                      color: Colors.black87,
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
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              if (_isLoadingHistory)
                                Center(
                                  child: CircularProgressIndicator(),
                                )
                              else if (_recentServices.isEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Belum ada riwayat service',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey[600],
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
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(16),
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
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  service.device
                                                          .contains('iphone')
                                                      ? Icons.phone_iphone
                                                      : Icons.phone_android,
                                                  color: Colors.blue,
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
                                                          .formatDeviceName({
                                                        'device':
                                                            service.device,
                                                        'brand': service.brand,
                                                        'model': service.model,
                                                      }),
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      DeviceProblems
                                                          .getProblemName(
                                                              service.problem),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 13,
                                                        color: Colors.grey[600],
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
                                                                service.status)
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child: Text(
                                                        service.status?.toUpperCase() ==
                                                                    'PENDING' &&
                                                                service.price !=
                                                                    null
                                                            ? 'Menunggu Pembayaran'
                                                            : _getStatusText(
                                                                service.status),
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              _getStatusColor(
                                                                  service
                                                                      .status),
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
                                      color: Colors.black87,
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
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: _supabase
                                    .from('testimonials')
                                    .select()
                                    .order('created_at', ascending: false)
                                    .limit(5),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Center(
                                        child: CircularProgressIndicator());
                                  }

                                  if (snapshot.hasError) {
                                    return Container(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 24),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Gagal memuat testimoni',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final testimonials = snapshot.data ?? [];

                                  if (testimonials.isEmpty) {
                                    return Container(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 24),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Belum ada testimoni',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: testimonials.map((testimonial) {
                                        return Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width -
                                              48, // Sesuaikan dengan lebar layar dikurangi padding
                                          margin: EdgeInsets.only(right: 12),
                                          padding: EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: Colors.grey[200]!,
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
                                                                  testimonial),
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: Colors
                                                                .grey[600],
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 16),
                                              Row(
                                                children: List.generate(
                                                  5,
                                                  (index) => Icon(
                                                    index <
                                                            (testimonial[
                                                                    'rating'] ??
                                                                0)
                                                        ? Icons.star
                                                        : Icons.star_border,
                                                    color: Colors.amber,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 12),
                                              Text(
                                                testimonial['content'],
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  height: 1.5,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 12),
                                              Text(
                                                DateFormat('dd MMMM yyyy')
                                                    .format(
                                                  DateTime.parse(testimonial[
                                                      'created_at']),
                                                ),
                                                style: GoogleFonts.poppins(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
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
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
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
                      color: Colors.red,
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
                      color: Colors.blue,
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

  String _getStatusText(String? status) {
    if (status == null) return 'Menunggu Admin';

    final service = _recentServices.firstWhere(
      (s) => s.status == status,
      orElse: () => ServiceModel.fromJson({}),
    );

    // Jika status PENDING dan ada service_cost, tampilkan "Menunggu Pembayaran"
    if (status.toUpperCase() == 'PENDING' && service.price != null) {
      return 'Menunggu Pembayaran';
    }

    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Menunggu Admin';
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

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.orange;

    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'PROCESSED':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'PAID':
        return Colors.green;
      case 'EXPIRED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
