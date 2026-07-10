import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicehponline/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:servicehponline/features/user/widgets/request_service_flow_widget.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async'; // Menambahkan import untuk StreamSubscription

class ProfileSetupPage extends StatefulWidget {
  final bool isFirstTime;

  const ProfileSetupPage({
    Key? key,
    this.isFirstTime = false,
  }) : super(key: key);

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressDetailController = TextEditingController();
  final _addressNoteController = TextEditingController();

  final _supabase = Supabase.instance.client;
  final _firebaseAuth = firebase_auth.FirebaseAuth.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  double _progress = 0.0;
  bool _isLoading = false;
  bool _isLocationLoading = false;
  BuildContext? _gpsDialogContext;
  bool _isGpsEnabled = false;
  StreamSubscription<ServiceStatus>? _gpsStatusSubscription;
  Timer? _gpsCheckTimer;

  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    _loadUserData();
    _setupGpsListener();
    _checkGPSStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _addressDetailController.dispose();
    _addressNoteController.dispose();
    _animationController.dispose();
    _gpsStatusSubscription?.cancel();
    _gpsCheckTimer?.cancel();
    super.dispose();
  }

  void _setupGpsListener() {
    _gpsStatusSubscription?.cancel();
    _gpsStatusSubscription = Geolocator.getServiceStatusStream().listen(
      (ServiceStatus status) async {
        print('GPS Status Changed: ${status.toString()}');
        if (status == ServiceStatus.enabled) {
          await _checkGPSAndCloseDialog();
        } else if (status == ServiceStatus.disabled) {
          if (mounted) {
            setState(() {
              _isGpsEnabled = false;
            });
            _showLocationServiceDisabledDialog();
          }
        }
      },
    );
  }

  Future<void> _checkGPSStatus() async {
    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (mounted) {
        setState(() {
          _isGpsEnabled = isEnabled;
        });
      }
    } catch (e) {
      print('Error checking initial GPS status: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Ketika aplikasi kembali ke foreground, mulai timer polling
      _startGpsPollingTimer();
      // Juga cek status GPS secara langsung
      _checkGPSAndCloseDialog();
    } else if (state == AppLifecycleState.paused) {
      // Ketika aplikasi ke background, hentikan timer polling
      _gpsCheckTimer?.cancel();
    }
  }

  void _startGpsPollingTimer() {
    // Batalkan timer yang sudah ada jika ada
    _gpsCheckTimer?.cancel();

    // Buat timer baru yang akan memeriksa status GPS setiap 1 detik
    _gpsCheckTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      // Hentikan timer jika widget sudah tidak mounted
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Jika dialog sedang ditampilkan, periksa status GPS
      if (_gpsDialogContext != null) {
        try {
          final isEnabled = await Geolocator.isLocationServiceEnabled();
          print('GPS Timer Check: ${isEnabled ? 'Enabled' : 'Disabled'}');

          // Jika GPS sudah aktif, tutup dialog
          if (isEnabled && mounted) {
            setState(() {
              _isGpsEnabled = true;
            });

            // Coba tutup dialog jika masih ada
            if (_gpsDialogContext != null) {
              // Gunakan try-catch untuk menghindari error jika dialog sudah ditutup
              try {
                Navigator.of(_gpsDialogContext!).pop();
                _gpsDialogContext = null;

                // Jalankan deteksi lokasi
                await Future.delayed(Duration(milliseconds: 500));
                if (!mounted) return;
                _detectLocation();

                // Hentikan timer setelah berhasil menutup dialog
                timer.cancel();
              } catch (e) {
                print('Error closing GPS dialog: $e');
              }
            }
          }
        } catch (e) {
          print('Error in GPS polling timer: $e');
        }
      } else {
        // Jika tidak ada dialog, tidak perlu polling lagi
        timer.cancel();
      }
    });
  }

  Future<void> _checkGPSAndCloseDialog() async {
    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      print('GPS Status Check: ${isEnabled ? 'Enabled' : 'Disabled'}');

      if (mounted) {
        setState(() {
          _isGpsEnabled = isEnabled;
        });

        if (isEnabled && _gpsDialogContext != null) {
          // Gunakan try-catch untuk menghindari error jika dialog sudah ditutup
          try {
            Navigator.of(_gpsDialogContext!).pop();
            _gpsDialogContext = null;

            // Mulai timer polling setelah user mengaktifkan GPS
            _startGpsPollingTimer();

            // Tunggu sebentar, lalu jalankan deteksi lokasi
            await Future.delayed(Duration(milliseconds: 500));
            if (!mounted) return;
            _detectLocation();
          } catch (e) {
            print('Error closing GPS dialog: $e');
            _gpsDialogContext = null;
          }
        }
      }
    } catch (e) {
      print('Error checking GPS status: $e');
    }
  }

  Future<void> _loadUserData() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profileData = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.uid)
          .maybeSingle();

      if (!mounted) return;

      print('Data profil dari Supabase:');
      if (profileData != null) {
        print('fullname: ${profileData['fullname']}');
        print('phoneNumber: ${profileData['phoneNumber']}');
        print('address: ${profileData['address']}');
        print('address_note: ${profileData['address_note']}');
      } else {
        print('Tidak ada data profil ditemukan');
      }
      print('Data dari Firebase Auth:');
      print('displayName: ${user.displayName}');
      print('phoneNumber: ${user.phoneNumber}');

      if (profileData != null) {
        setState(() {
          _nameController.text =
              profileData['fullname'] ?? user.displayName ?? '';

          // Dapatkan data phoneNumber dari Supabase
          _whatsappController.text = profileData['phoneNumber'] ?? '';

          // Gunakan address dari Supabase jika ada
          _addressController.text = profileData['address'] ?? '';

          // Gunakan address dari Supabase sebagai detail alamat
          _addressDetailController.text = profileData['address'] ?? '';

          _addressNoteController.text = profileData['address_note'] ?? '';

          _updateProgress();
        });
      } else {
        // Set nama dari akun Google jika tersedia
        setState(() {
          _nameController.text = user.displayName ?? '';
          _whatsappController.text =
              ''; // Jangan gunakan phoneNumber karena bisa null

          _updateProgress();
        });
      }
    } catch (e) {
      print('Error loading profile data: $e');
      if (!mounted) return;
      // Set nama dari akun Google jika tersedia
      setState(() {
        _nameController.text = user.displayName ?? '';
        _whatsappController.text =
            ''; // Jangan gunakan phoneNumber karena bisa null

        _updateProgress();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateProgress() {
    double progress = 0.0;
    int filledFields = 0;
// Total ada 3 field wajib: nama, phoneNumber, dan alamat detail

    if (_nameController.text.isNotEmpty) filledFields++;
    if (_whatsappController.text.isNotEmpty) filledFields++;
    if (_addressDetailController.text.isNotEmpty) filledFields++;

    // Hitung berdasarkan step saat ini
    if (_currentStep == 0) {
      // Di step pertama, hanya hitung nama dan WhatsApp (2 field)
      progress = filledFields / 2;

      // Pastikan progress maksimal 0.5 (50%) jika hanya di step pertama
      progress = progress > 0.5 ? 0.5 : progress;
    } else {
      // Di step kedua, hitung semua field (nama, WhatsApp, alamat)
      // Bobot: 50% untuk step 1 + 50% untuk step 2
      if (_nameController.text.isNotEmpty &&
          _whatsappController.text.isNotEmpty) {
        progress = 0.5; // Data step 1 lengkap

        // Tambah progress dari alamat detail
        if (_addressDetailController.text.isNotEmpty) {
          progress += 0.5; // Tambah 50% jika alamat detail sudah diisi
        }
      } else {
        // Jika data step 1 belum lengkap
        progress = (_nameController.text.isNotEmpty ? 0.25 : 0) +
            (_whatsappController.text.isNotEmpty ? 0.25 : 0);

        // Tambah progress dari alamat detail dengan proporsi yang tepat
        if (_addressDetailController.text.isNotEmpty) {
          progress += 0.5;
        }
      }
    }

    setState(() => _progress = progress);
  }

  Future<void> _detectLocation() async {
    setState(() => _isLocationLoading = true);

    try {
      // Cek apakah layanan lokasi aktif
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        setState(() => _isLocationLoading = false);
        setState(() => _isGpsEnabled = false);
        _showLocationServiceDisabledDialog();
        return;
      }

      setState(() => _isGpsEnabled = true);

      // Cek izin lokasi
      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Izin lokasi ditolak')),
          );
          setState(() => _isLocationLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocationLoading = false);
        _showLocationPermissionDeniedDialog();
        return;
      }

      // Dapatkan posisi
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      // Dapatkan alamat dari koordinat dengan prioritas mendapatkan nama jalan
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        localeIdentifier:
            'id_ID', // Gunakan locale Indonesia untuk format alamat yang sesuai
      );
      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Debug untuk memeriksa semua properti dari place
        print('===== PLACEMARK DEBUG =====');
        print('Name: ${place.name}');
        print('Street: ${place.street}');
        print('Thoroughfare: ${place.thoroughfare}');
        print('SubThoroughfare: ${place.subThoroughfare}');
        print('Locality: ${place.locality}');
        print('SubLocality: ${place.subLocality}');
        print('Administrative Area: ${place.administrativeArea}');
        print('SubAdministrative Area: ${place.subAdministrativeArea}');
        print('Postal Code: ${place.postalCode}');
        print('Country: ${place.country}');
        print('===========================');

        // Fungsi untuk mengecek apakah sebuah string berisi format plus code
        bool containsPlusCode(String? text) {
          if (text == null || text.isEmpty) return false;
          // Plus code biasanya dalam format seperti "44Q9+XV7" atau sejenisnya
          return RegExp(r'\b[0-9A-Z]{4}\+[0-9A-Z]{2,3}\b').hasMatch(text);
        }

        // Jika ada properti yang mengandung plus code, ganti dengan string kosong atau null
        String? safeName = (place.name != null && !containsPlusCode(place.name))
            ? place.name
            : null;
        String? safeStreet =
            (place.street != null && !containsPlusCode(place.street))
                ? place.street
                : null;
        String? safeThoroughfare = (place.thoroughfare != null &&
                !containsPlusCode(place.thoroughfare))
            ? place.thoroughfare
            : null;

        // Bangun alamat baru tanpa plus code
        String address = '';
        String detailAddress = '';

        // Prioritaskan nama jalan yang bermakna
        if (safeThoroughfare != null && safeThoroughfare.isNotEmpty) {
          address += safeThoroughfare;
          if (place.subThoroughfare != null &&
              place.subThoroughfare!.isNotEmpty) {
            address += ' No. ' + place.subThoroughfare!;
          }
          address += ', ';
        } else if (safeStreet != null && safeStreet.isNotEmpty) {
          address += safeStreet + ', ';
        }

        // Tambahkan informasi kelurahan/desa jika tersedia dan bukan plus code
        if (place.subLocality != null &&
            place.subLocality!.isNotEmpty &&
            !containsPlusCode(place.subLocality)) {
          address += place.subLocality! + ', ';
        }

        // Tambahkan informasi kecamatan jika tersedia dan bukan plus code
        if (place.locality != null &&
            place.locality!.isNotEmpty &&
            !containsPlusCode(place.locality)) {
          address += place.locality! + ', ';
        }

        // Tambahkan informasi kabupaten/kota jika tersedia dan bukan plus code
        if (place.subAdministrativeArea != null &&
            place.subAdministrativeArea!.isNotEmpty &&
            !containsPlusCode(place.subAdministrativeArea)) {
          address += place.subAdministrativeArea! + ', ';
        }

        // Tambahkan informasi provinsi jika tersedia dan bukan plus code
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty &&
            !containsPlusCode(place.administrativeArea)) {
          address += place.administrativeArea! + ', ';
        }

        // Tambahkan kode pos jika tersedia
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          address += place.postalCode!;
        }

        // Hapus koma ekstra di akhir jika ada
        address = address.replaceAll(RegExp(r', $'), '');

        // Jika alamat kosong karena semua komponen mengandung plus code,
        // gunakan alamat default yang lebih bermakna
        if (address.trim().isEmpty) {
          // Gunakan lokasi di kota/kabupaten dan provinsi jika tersedia
          if (place.subAdministrativeArea != null &&
              !containsPlusCode(place.subAdministrativeArea)) {
            address = "Lokasi di ${place.subAdministrativeArea}";
            if (place.administrativeArea != null &&
                !containsPlusCode(place.administrativeArea)) {
              address += ", ${place.administrativeArea}";
            }
          } else if (place.administrativeArea != null &&
              !containsPlusCode(place.administrativeArea)) {
            address = "Lokasi di ${place.administrativeArea}";
          } else {
            // Fallback jika semua komponen adalah plus code
            address = "Alamat terdeteksi";
          }
        }

        // Buat detail alamat dengan nama tempat (jika bermakna) di awal
        detailAddress = address;

        // Tambahkan nama tempat di awal jika bermakna dan bukan plus code
        if (safeName != null && safeName.isNotEmpty) {
          detailAddress = safeName + ", " + detailAddress;
        }

        setState(() {
          _addressController.text = address;
          _addressDetailController.text = detailAddress;
          _updateProgress();
        });

        // Feedback haptic
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      print('Error detecting location: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mendeteksi lokasi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

  void _showLocationServiceDisabledDialog() {
    // Cek apakah dialog sudah ditampilkan atau GPS sudah aktif
    if (_gpsDialogContext != null || _isGpsEnabled) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Simpan reference dialog
        _gpsDialogContext = dialogContext;

        // Mulai timer untuk polling status GPS
        _startGpsPollingTimer();

        return WillPopScope(
          onWillPop: () async {
            bool isEnabled = await Geolocator.isLocationServiceEnabled();
            if (!mounted) return false;
            if (isEnabled) {
              setState(() => _isGpsEnabled = true);
              _gpsDialogContext = null;
              return true;
            }
            return false;
          },
          child: AlertDialog(
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
                  color: Theme.of(context).colorScheme.error,
                ),
                SizedBox(height: 16),
                Text(
                  'Aplikasi membutuhkan akses lokasi untuk mendeteksi alamat Anda. Silakan aktifkan GPS pada perangkat Anda.',
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
                      onPressed: () async {
                        await Geolocator.openLocationSettings();
                      },
                      child: Text(
                        'AKTIFKAN GPS',
                        style: GoogleFonts.poppins(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // Reset dialog context
      _gpsDialogContext = null;
      // Batalkan timer polling ketika dialog ditutup
      _gpsCheckTimer?.cancel();
    });
  }

  void _showLocationPermissionDeniedDialog() {
    // Cek apakah dialog sudah ditampilkan
    if (_gpsDialogContext != null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Simpan reference dialog
        _gpsDialogContext = dialogContext;

        return WillPopScope(
          onWillPop: () async {
            LocationPermission permission = await Geolocator.checkPermission();
            if (permission != LocationPermission.denied &&
                permission != LocationPermission.deniedForever) {
              _gpsDialogContext = null;
              return true;
            }
            return false;
          },
          child: AlertDialog(
            title: Text(
              'Izin Lokasi Ditolak',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_disabled,
                  size: 64,
                  color: AppColors.warning,
                ),
                SizedBox(height: 16),
                Text(
                  'Aplikasi memerlukan izin lokasi untuk mendeteksi alamat Anda. Silakan berikan izin lokasi pada pengaturan aplikasi.',
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
                      'BUKA PENGATURAN',
                      style: GoogleFonts.poppins(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () async {
                      await Geolocator.openAppSettings();
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
      // Reset dialog context
      _gpsDialogContext = null;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Validasi tambahan untuk alamat detail
    if (_addressDetailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Detail alamat wajib diisi')),
      );
      return;
    }

    // Validasi tambahan untuk nomor WhatsApp
    if (!_validateWhatsAppFormat()) {
      return;
    }
    String whatsappNumber =
        _whatsappController.text.replaceAll(RegExp(r'[^\d]'), '');

    setState(() => _isLoading = true);

    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception('User tidak terautentikasi');

      // Gunakan alamat detail sebagai alamat utama
      String addressDetail = _addressDetailController.text.trim();
      // Pastikan catatan alamat tidak null
      String addressNote = _addressNoteController.text.trim();

      // Debug - print nilai yang akan disimpan
      print('Saving Profile Data:');
      print('ID: ${user.uid}');
      print('Fullname: ${_nameController.text.trim()}');
      print('PhoneNumber: $whatsappNumber');
      print('Address: $addressDetail');
      print('Address Note: $addressNote');

      // Data profil yang akan disimpan
      final profileData = {
        'id': user.uid,
        'fullname': _nameController.text.trim(),
        'phoneNumber': whatsappNumber,
        'address': addressDetail,
        'address_note': addressNote,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Cek apakah profil sudah ada di database
      print(
          'Memeriksa profil yang sudah ada di Supabase untuk UID: ${user.uid}');
      final existingProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.uid)
          .maybeSingle();

      // Debug info
      if (existingProfile != null) {
        print('Data profil yang ada di database:');
        print('fullname: ${existingProfile['fullname']}');
        print('phoneNumber: ${existingProfile['phoneNumber']}');
        print('address: ${existingProfile['address']}');
        print('address_note: ${existingProfile['address_note']}');
      }

      if (existingProfile != null) {
        // Update profil yang sudah ada
        print('Profil ditemukan, melakukan UPDATE dengan data baru');
        await _supabase.from('profiles').update(profileData).eq('id', user.uid);
        print('Profil berhasil diperbarui');
      } else {
        // Insert profil baru
        print('Profil tidak ditemukan, membuat profil BARU');
        profileData['created_at'] = DateTime.now().toIso8601String();
        await _supabase.from('profiles').insert(profileData);
        print('Profil baru berhasil dibuat');
      }

      // Simpan flag profil selesai
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('profile_complete', true);
      print('Flag profile_complete diset ke TRUE');

      // Feedback haptic
      HapticFeedback.mediumImpact();

      if (!mounted) return;

      // Konfirmasi sukses
      AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        animType: AnimType.bottomSlide,
        title: 'Profil Berhasil Disimpan',
        desc: 'Profil Anda berhasil disimpan. Selamat menggunakan aplikasi!',
        btnOkText: 'Lanjutkan',
        btnOkColor: Theme.of(context).colorScheme.primary,
        btnOkOnPress: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  RequestServiceFlow(username: _nameController.text),
            ),
          );
        },
      ).show();
    } catch (e) {
      print('Error saving profile: $e');

      if (!mounted) return;

      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.bottomSlide,
        title: 'Gagal Menyimpan Profil',
        desc: 'Terjadi kesalahan saat menyimpan profil: $e',
        btnOkText: 'Coba Lagi',
        btnOkColor: Theme.of(context).colorScheme.primary,
        btnOkOnPress: () {},
      ).show();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _cancelProfileSetup() {
    if (widget.isFirstTime) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.bottomSlide,
        title: 'Yakin Ingin Keluar?',
        desc:
            'Kamu bisa lengkapi profil nanti di menu Akun. Lanjut ke beranda?',
        btnOkText: 'Ya, Lanjutkan',
        btnOkOnPress: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => RequestServiceFlow(
                username: _nameController.text.isEmpty
                    ? 'Pengguna'
                    : _nameController.text,
              ),
            ),
          );
        },
        btnCancelText: 'Batal',
        btnCancelOnPress: () {},
      ).show();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _nextStep() {
    if (_currentStep < 1) {
      // Validasi format nomor WhatsApp sebelum lanjut ke step selanjutnya
      if (!_validateWhatsAppFormat()) {
        return;
      }
      setState(() {
        _currentStep++;
        _updateProgress(); // Update progress saat pindah step
      });
    } else {
      _saveProfile();
    }
  }

  // Fungsi validasi format WhatsApp terpisah
  bool _validateWhatsAppFormat() {
    String whatsappNumber =
        _whatsappController.text.replaceAll(RegExp(r'[^\d]'), '');

    // Periksa apakah kosong
    if (whatsappNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nomor WhatsApp wajib diisi')),
      );
      return false;
    }

    // Format nomor
    if (whatsappNumber.startsWith('0')) {
      whatsappNumber = '62${whatsappNumber.substring(1)}';
    } else if (!whatsappNumber.startsWith('62')) {
      whatsappNumber = '62$whatsappNumber';
    }

    // Validasi panjang
    if (whatsappNumber.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Nomor WhatsApp terlalu pendek (min. 11 digit dengan kode 62)')),
      );
      return false;
    }

    if (whatsappNumber.length > 13) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Nomor WhatsApp terlalu panjang (maks. 13 digit dengan kode 62)')),
      );
      return false;
    }

    // Jika lolos semua validasi, update format di controller
    if (_whatsappController.text != whatsappNumber) {
      _whatsappController.text = whatsappNumber;
    }

    return true;
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      _cancelProfileSetup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return WillPopScope(
      onWillPop: () async {
        _cancelProfileSetup();
        return false;
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Text(
            'Pengaturan Profil',
            style: GoogleFonts.poppins(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () => _cancelProfileSetup(),
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isFirstTime
                              ? "Lengkapi profilmu dulu, ya! Cuma 1 menit 😊"
                              : "Lengkapi profilmu untuk unlock fitur eksklusif!",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(colorScheme.primary),
                          borderRadius: BorderRadius.circular(8),
                          minHeight: 10,
                        ),
                        SizedBox(height: 4),
                        Text(
                          "${(_progress * 100).toInt()}% Lengkap",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          onChanged: _updateProgress,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_currentStep == 0) ...[
                                _buildInfoData(),
                              ] else ...[
                                _buildLocationData(),
                              ],
                            ],
                          ),
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

  Widget _buildInfoData() {
    final colorScheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Informasi Pribadi",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Informasi ini akan digunakan untuk layanan service",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 24),

          // Nama Lengkap
          Row(
            children: [
              Text(
                "Nama Lengkap",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(width: 8),
              Text(
                "(Wajib Diisi)",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: "Masukkan nama lengkap",
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama lengkap wajib diisi';
              }
              return null;
            },
          ),
          SizedBox(height: 24),

          // Nomor WhatsApp
          Row(
            children: [
              Text(
                "Nomor WhatsApp",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(width: 8),
              Text(
                "(Wajib Diisi)",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: _whatsappController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              LengthLimitingTextInputFormatter(13), // Batasi maksimal 13 digit
              FilteringTextInputFormatter.digitsOnly, // Hanya boleh angka
            ],
            decoration: InputDecoration(
              hintText: "Contoh: 081234567890",
              prefixIcon: Icon(Icons.phone_android),
              helperText: "Format: Diawali dengan 0 atau 62, total 11-13 digit",
              helperStyle: GoogleFonts.poppins(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              errorMaxLines: 2,
            ),
            onChanged: (value) {
              if (value.isNotEmpty && value.startsWith('0')) {
                // Auto-format saat mengetik jika dimulai dengan 0
                String formatted = '62${value.substring(1)}';
                _whatsappController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nomor WhatsApp wajib diisi';
              }

              String cleanNumber = value.replaceAll(RegExp(r'[^\d]'), '');

              // Jika masih menggunakan awalan 0, ubah ke format 62
              if (cleanNumber.startsWith('0')) {
                cleanNumber = '62${cleanNumber.substring(1)}';
              } else if (!cleanNumber.startsWith('62')) {
                // Jika tidak dimulai dengan 0 atau 62, tambahkan 62 di depannya
                cleanNumber = '62$cleanNumber';
              }

              // Cek panjang nomor setelah diformat
              if (cleanNumber.length < 11) {
                return 'Nomor WhatsApp terlalu pendek (min. 11 digit dengan kode 62)';
              }

              if (cleanNumber.length > 13) {
                return 'Nomor WhatsApp terlalu panjang (maks. 13 digit dengan kode 62)';
              }

              // Format ulang input field untuk konsistensi tampilan
              if (cleanNumber != value) {
                Future.microtask(() {
                  _whatsappController.text = cleanNumber;
                });
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationData() {
    final colorScheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Alamat Detail",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Alamat ini akan digunakan untuk pengiriman/penjemputan perangkat",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _isLocationLoading ? null : _detectLocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              foregroundColor: colorScheme.primary,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.4)),
              ),
            ),
            icon: _isLocationLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    ),
                  )
                : Icon(Icons.my_location),
            label: Text(
              _isLocationLoading
                  ? "Mendeteksi Lokasi..."
                  : "Deteksi Lokasi Otomatis",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(height: 24),

          // Detail Alamat
          Row(
            children: [
              Text(
                "Detail Alamat",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(width: 8),
              Text(
                "(Wajib Diisi)",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: _addressDetailController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Contoh: Jl. Sudirman No. 123, RT 001/RW 002",
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Detail alamat wajib diisi';
              }
              return null;
            },
            onChanged: (value) {
              _updateProgress(); // Update progress saat alamat detail diubah
            },
          ),
          SizedBox(height: 24),

          // Catatan Alamat
          Row(
            children: [
              Text(
                "Catatan Alamat",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(width: 8),
              Text(
                "(Opsional)",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: _addressNoteController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Contoh: Lantai 2, Patokan Warung, dll",
              prefixIcon: Icon(Icons.note_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    final colorScheme = Theme.of(context).colorScheme;
    bool isFirstStepInputValid = _nameController.text.isNotEmpty &&
        _whatsappController.text.isNotEmpty &&
        _whatsappController.text.length >= 11;

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
      child: Row(
        children: [
          if (_currentStep > 0 || widget.isFirstTime)
            Expanded(
              child: TextButton(
                onPressed: _isLoading ? null : _prevStep,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outline),
                  ),
                ),
                child: Text(
                  _currentStep > 0 ? "KEMBALI" : "NANTI SAJA",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0 || widget.isFirstTime) SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_currentStep == 0
                      ? (isFirstStepInputValid ? _nextStep : null)
                      : _saveProfile),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                      ),
                    )
                  : Text(
                      _currentStep < 1 ? "LANJUT" : "SIMPAN PROFIL",
                      style: GoogleFonts.poppins(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
