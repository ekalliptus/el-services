import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:servicehponline/core/services/authentication.dart';
import 'package:servicehponline/features/profile/pages/profile_setup_page.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:servicehponline/features/admin/pages/super_admin_dashboard.dart';
import 'package:servicehponline/features/admin/pages/admin_dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:servicehponline/features/user/widgets/request_service_flow_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:servicehponline/blocs/auth/auth_bloc.dart';
import 'package:servicehponline/blocs/auth/auth_event.dart';
import 'package:servicehponline/blocs/auth/auth_state.dart';
import 'package:provider/provider.dart';
import 'package:servicehponline/core/services/update_service.dart';
import 'package:servicehponline/core/services/secure_store.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _formKey = GlobalKey<FormState>();
  final _adminFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _authentication = Authentication();
  final _supabase = Supabase.instance.client;
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _isChecked = false;
  bool _isGoogleLoading = false;
  bool _isWhatsappLoading = false;
  bool _isAdminLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();

    // Periksa pembaruan aplikasi setiap kali halaman login dimuat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAppUpdates();
    });

    // Navigasi pasca-autentikasi ditangani secara terpusat oleh BlocListener
    // di build(). Listener stream terpisah dihapus agar tidak terjadi navigasi
    // ganda (triple-navigation) pada alur login.
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    if (!_isChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Anda harus menyetujui Ketentuan Layanan dan Kebijakan Privasi terlebih dahulu'),
        ),
      );
      return;
    }

    setState(() => _isGoogleLoading = true);

    try {
      final userCredential = await _authentication.signInWithGoogle();
      if (!mounted) return;

      if (userCredential != null && userCredential.user != null) {
        print('Google Sign In successful: ${userCredential.user?.displayName}');
        context.read<AuthBloc>().add(AuthTermsAccepted(true));
        context.read<AuthBloc>().add(AuthLoginSuccess(userCredential.user!));

        // Periksa status login user (hanya menyetel flag; navigasi ditangani
        // oleh BlocListener saat state AuthAuthenticated diterima).
        if (userCredential.user != null) {
          await _checkUserLogin(userCredential.user!);
        }
        return;
      } else {
        print('Google Sign In cancelled or failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login dibatalkan')),
          );
        }
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      print('Error during Google Sign In: $e');
      if (!mounted) return;

      if (!e.toString().contains('PigeonUserDetails')) {
        String errorMessage = 'Gagal masuk dengan Google';
        if (e.toString().contains('network_error')) {
          errorMessage = 'Gagal terhubung ke internet. Silakan coba lagi.';
        } else if (e.toString().contains('sign_in_failed')) {
          errorMessage = 'Gagal masuk. Silakan coba lagi.';
        } else if (e.toString().contains('sign_in_canceled')) {
          errorMessage = 'Login dibatalkan.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }


  // Tambahkan fungsi untuk memeriksa user yang sudah login
  Future<void> _checkUserLogin(firebase_auth.User user) async {
    print('USER LOGIN TERDETEKSI: ${user.uid}');
    print('DisplayName: ${user.displayName}');
    print('Email: ${user.email}');
    print('Firebase PhoneNumber: ${user.phoneNumber}');
    print('PhotoURL: ${user.photoURL}');

    try {
      final prefs = await SharedPreferences.getInstance();

      // Set flag onboarding dan profile complete terlebih dahulu sebagai fallback
      try {
        await prefs.setBool('has_completed_onboarding', true);
        await prefs.setBool('profile_complete', true);
        print('Flag initial onboarding dan profile complete berhasil disetel');
      } catch (flagError) {
        print('Error setting initial flags in _checkUserLogin: $flagError');
      }

      // Cek apakah user sudah memiliki profil di Supabase
      try {
        final profile = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.uid)
            .maybeSingle();

        if (profile != null) {
          // User sudah memiliki profil di Supabase
          await prefs.setBool('has_completed_onboarding', true);
          await prefs.setBool('profile_complete', true);
          print(
              'User telah menyelesaikan onboarding (profil ditemukan di Supabase)');
          print('Data profil: ${profile.toString()}');
        } else {
          print(
              'User belum menyelesaikan onboarding (tidak ada profil di Supabase)');
        }
      } catch (profileError) {
        print('Error memeriksa profil di _checkUserLogin: $profileError');
        // Pastikan flag tetap disetel meskipun terjadi error
        try {
          await prefs.setBool('has_completed_onboarding', true);
          await prefs.setBool('profile_complete', true);
          print(
              'Flag onboarding dan profile complete disetel ulang setelah error');
        } catch (flagError) {
          print('Error setting flags after profile check error: $flagError');
        }
      }
    } catch (e) {
      print('Error memeriksa status login user: $e');
    }
  }

  // Fungsi untuk menampilkan dialog login admin
  Future<void> _showAdminLoginDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Login Admin',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _adminFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _adminEmailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email tidak boleh kosong';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Email tidak valid';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _adminPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _adminEmailController.clear();
                _adminPasswordController.clear();
              },
              child: Text(
                'BATAL',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _isAdminLoading
                  ? null
                  : () async {
                      if (_adminFormKey.currentState!.validate()) {
                        setState(() => _isAdminLoading = true);
                        try {
                          // Login terlebih dahulu dengan Supabase
                          final email = _adminEmailController.text.trim();
                          print('Mencoba login dengan email: $email');

                          final response =
                              await _supabase.auth.signInWithPassword(
                            email: email,
                            password: _adminPasswordController.text,
                          );

                          if (!mounted) return;

                          if (response.user != null) {
                            try {
                              // Mendapatkan userId dari hasil login
                              final userId = response.user!.id;
                              print(
                                  'Login berhasil, mendapatkan userId: $userId');
                              print('Memeriksa apakah user adalah admin...');

                              // Cek di tabel admins berdasarkan ID
                              final adminCheck = await _supabase
                                  .from('admins')
                                  .select('*')
                                  .eq('id', userId)
                                  .maybeSingle();

                              print(
                                  'Hasil pemeriksaan admin: ${adminCheck != null ? "Ditemukan" : "Tidak ditemukan"}');

                              if (adminCheck != null) {
                                // Periksa apakah super admin
                                final isSuperAdmin =
                                    adminCheck['role'] == 'super_admin';

                                print(
                                    'Verifikasi admin berhasil. isSuperAdmin: $isSuperAdmin');

                                // Simpan sesi admin
                                final session = response.session;
                                if (session != null) {
                                  await _saveAdminSession(session);
                                }

                                if (!mounted) return;
                                Navigator.of(context).pop();

                                // Arahkan berdasarkan tipe admin
                                if (isSuperAdmin) {
                                  // Arahkan ke halaman super admin
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SuperAdminDashboard(),
                                    ),
                                    (route) => false,
                                  );
                                } else {
                                  // Arahkan ke halaman admin biasa
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AdminDashboardPage(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              } else {
                                // Bukan admin, lakukan logout
                                print('Bukan admin, melakukan logout');
                                await _supabase.auth.signOut();

                                throw Exception(
                                    'Akun ini tidak terdaftar sebagai admin.');
                              }
                            } catch (e) {
                              print('Error saat verifikasi admin: $e');
                              // Logout jika gagal verifikasi
                              await _supabase.auth.signOut();
                              throw e;
                            }
                          } else {
                            throw Exception(
                                'Login gagal: Response tidak valid');
                          }
                        } catch (e) {
                          print('Login error: $e');
                          if (!mounted) return;

                          String errorMessage = 'Terjadi kesalahan';
                          if (e
                              .toString()
                              .contains('Invalid login credentials')) {
                            errorMessage = 'Email atau password salah';
                          } else if (e.toString().contains(
                              'Akun ini tidak terdaftar sebagai admin')) {
                            errorMessage =
                                'Akun ini tidak terdaftar sebagai admin';
                          } else if (e.toString().contains(
                              'Akun ini tidak memiliki hak akses admin')) {
                            errorMessage =
                                'Akun ini tidak memiliki hak akses admin';
                          } else if (e.toString().contains('network')) {
                            errorMessage = 'Gagal terhubung ke server';
                          } else if (e.toString().contains('column')) {
                            errorMessage =
                                'Terjadi kesalahan database. Silakan hubungi developer.';
                          } else {
                            // Tambahkan detail error untuk membantu debugging
                            errorMessage =
                                'Gagal login admin: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}';
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(errorMessage),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _isAdminLoading = false);
                          }
                        }
                      }
                    },
              child: _isAdminLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    )
                  : Text(
                      'LOGIN',
                      style: GoogleFonts.poppins(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  // Simpan sesi admin
  Future<void> _saveAdminSession(Session session) async {
    try {
      // Simpan data sesi ke secure storage (Keystore/Keychain), bukan plaintext
      final sessionData = {
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken,
        'expires_at': session.expiresAt,
        'user_id': session.user.id,
        'email': session.user.email,
      };

      await SecureStore.writeAdminSession(jsonEncode(sessionData));
      print('Admin session saved securely');
    } catch (e) {
      print('Error saving admin session: $e');
    }
  }

  // Cek apakah sudah ada sesi admin yang tersimpan
  Future<void> _checkExistingSession() async {
    try {
      final adminSessionStr = await SecureStore.readAdminSession();

      if (adminSessionStr != null) {
        print('Found existing admin session, attempting to restore...');

        try {
          // Parse session data
          final sessionData = jsonDecode(adminSessionStr);

          // Coba refresh session menggunakan refresh token
          if (sessionData['refresh_token'] != null) {
            try {
              final response = await _supabase.auth.refreshSession();
              final newSession = response.session;
              if (newSession != null) {
                // Simpan sesi baru
                await _saveAdminSession(newSession);

                // Verifikasi bahwa user masih admin
                final adminCheck = await _supabase
                    .from('admins')
                    .select('*')
                    .eq('id', newSession.user.id)
                    .maybeSingle();

                if (adminCheck != null) {
                  final isSuperAdmin = adminCheck['role'] == 'super_admin';
                  print('Admin session refreshed and verified successfully');

                  if (mounted) {
                    if (isSuperAdmin) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const SuperAdminDashboard(),
                        ),
                        (route) => false,
                      );
                    } else {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const AdminDashboardPage(),
                        ),
                        (route) => false,
                      );
                    }
                    return;
                  }
                }
              }
            } catch (e) {
              print('Error refreshing session: $e');
            }
          }

          // Jika refresh gagal, coba pulihkan sesi dengan refresh token.
          // Supabase setSession() menerima REFRESH token, bukan access token.
          final refreshToken = sessionData['refresh_token'];
          if (refreshToken == null) {
            print('Tidak ada refresh token tersimpan; sesi tidak dapat dipulihkan');
            await _clearAdminSession();
            return;
          }
          await _supabase.auth.setSession(refreshToken);

          // Verifikasi sesi
          final currentSession = await _supabase.auth.currentSession;
          if (currentSession != null) {
            // Verifikasi bahwa user masih admin
            final adminCheck = await _supabase
                .from('admins')
                .select('*')
                .eq('id', currentSession.user.id)
                .maybeSingle();

            if (adminCheck != null) {
              final isSuperAdmin = adminCheck['role'] == 'super_admin';
              print('Admin session restored successfully');

              if (mounted) {
                if (isSuperAdmin) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const SuperAdminDashboard(),
                    ),
                    (route) => false,
                  );
                } else {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const AdminDashboardPage(),
                    ),
                    (route) => false,
                  );
                }
                return;
              }
            }
          }

          // Jika sampai di sini berarti sesi tidak valid
          print('Session invalid or user is not admin anymore');
          await _clearAdminSession();
        } catch (e) {
          print('Error restoring admin session: $e');
          await _clearAdminSession();
        }
      }
    } catch (e) {
      print('Error checking admin session: $e');
    }
  }

  // Hapus sesi admin
  Future<void> _clearAdminSession() async {
    try {
      await SecureStore.clearAdminSession();
      await _supabase.auth.signOut();
      print('Admin session cleared successfully');
    } catch (e) {
      print('Error clearing admin session: $e');
    }
  }

  // Fungsi untuk memeriksa pembaruan aplikasi
  void _checkForAppUpdates() async {
    try {
      // Dapatkan layanan pembaruan dari provider jika tersedia
      final updateService = Provider.of<UpdateService>(context, listen: false);

      // Periksa apakah sudah waktunya untuk memeriksa pembaruan
      bool shouldCheck = await updateService.shouldCheckForUpdates();
      if (!shouldCheck) {
        print('Home: Belum waktunya memeriksa pembaruan. Melewati...');
        return;
      }

      // Periksa pembaruan aplikasi
      final updateInfo = await updateService.checkAppVersion();

      // Jika ada pembaruan tersedia, tampilkan banner pembaruan
      if (updateInfo != null && mounted) {
        // Jalankan di microtask agar tidak mengganggu proses rendering
        Future.microtask(() {
          // Gunakan banner untuk halaman login daripada dialog penuh
          updateService.showUpdateBanner(context, updateInfo);
        });
      }
    } catch (e) {
      print('Error saat memeriksa pembaruan di Home: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        print('Auth state changed: $state');
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is AuthAuthenticated) {
          print('AUTENTIKASI BERHASIL: ${state.user.uid}');
          print('DisplayName: ${state.user.displayName}');
          print('Email: ${state.user.email}');
          print('Firebase PhoneNumber: ${state.user.phoneNumber}');

          // LANGSUNG periksa data profil di Supabase tanpa memeriksa flag onboarding dulu
          SharedPreferences.getInstance().then((prefs) {
            print(
                'Memeriksa profil Supabase untuk menentukan navigasi selanjutnya');
            final supabaseClient = Supabase.instance.client;

            print('Mencari profil untuk UID: ${state.user.uid}');
            supabaseClient
                .from('profiles')
                .select()
                .eq('id', state.user.uid)
                .maybeSingle()
                .then((profileData) {
              if (profileData != null) {
                print('PROFIL DITEMUKAN di Supabase:');
                print('fullname: ${profileData['fullname']}');
                print('phoneNumber: ${profileData['phoneNumber']}');
                print('whatsapp: ${profileData['whatsapp']}');
                print('address: ${profileData['address']}');

                // Jika pengguna sudah memiliki profil di Supabase, anggap sudah pernah onboarding
                prefs.setBool('has_completed_onboarding', true);

                // Tandai profil sebagai lengkap jika data utama tersedia
                bool isProfileComplete = profileData['fullname'] != null &&
                    profileData['phoneNumber'] != null &&
                    profileData['address'] != null;

                // Pastikan nilai tidak null sebelum mengakses
                print(
                    'Status kelengkapan profil (isProfileComplete): $isProfileComplete');
                print('Detail pengecekan:');
                print('fullname: ${profileData['fullname']}');
                print('phoneNumber: ${profileData['phoneNumber']}');
                print('address: ${profileData['address']}');

                // Update flag
                prefs.setBool('profile_complete', isProfileComplete);

                // Selalu arahkan ke halaman utama jika profil ditemukan di Supabase,
                // terlepas dari kelengkapan profil
                print('PROFIL DITEMUKAN - mengarahkan ke halaman utama');

                // Gunakan nilai default untuk username jika null
                String username = 'User';
                if (profileData['fullname'] != null &&
                    profileData['fullname'].toString().isNotEmpty) {
                  username = profileData['fullname'];
                } else if (state.user.displayName != null &&
                    state.user.displayName!.isNotEmpty) {
                  username = state.user.displayName!;
                }

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => RequestServiceFlow(
                      username: username,
                    ),
                  ),
                  (route) => false,
                );
              } else {
                print('PROFIL TIDAK DITEMUKAN di Supabase');
                // Arahkan langsung ke halaman pengaturan profil untuk membuat profil baru
                // tanpa memeriksa status onboarding
                print(
                    'PROFIL TIDAK DITEMUKAN - mengarahkan ke pengaturan profil');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) =>
                        const ProfileSetupPage(isFirstTime: true),
                  ),
                  (route) => false,
                );
              }
            }).catchError((e) {
              print('ERROR memeriksa profil di Supabase: $e');

              // Jika gagal memeriksa profil, gunakan fallback ke halaman utama
              print('ERROR - mengarahkan ke halaman utama sebagai fallback');

              // Pastikan profil dianggap lengkap untuk mencegah redirect ke setup profil
              try {
                prefs.setBool('has_completed_onboarding', true);
                prefs.setBool('profile_complete', true);
              } catch (prefError) {
                print('Error menyimpan ke SharedPreferences: $prefError');
              }

              // Tambahkan delay untuk memastikan SharedPreferences disimpan
              Future.delayed(Duration(milliseconds: 100), () {
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => RequestServiceFlow(
                      username: state.user.displayName ?? 'User',
                    ),
                  ),
                  (route) => false,
                );
              });
            });
          }).catchError((e) {
            print('Error mengakses SharedPreferences: $e');

            // Fallback jika terjadi error saat mengakses SharedPreferences
            // Pastikan profil dianggap lengkap
            SharedPreferences.getInstance().then((prefs) {
              try {
                prefs.setBool('has_completed_onboarding', true);
                prefs.setBool('profile_complete', true);
              } catch (prefError) {
                print(
                    'Error menyimpan ke SharedPreferences fallback: $prefError');
              }
            }).catchError((prefError) {
              print('Tidak bisa mengakses SharedPreferences: $prefError');
            });

            // Tambahkan delay untuk memastikan SharedPreferences disimpan
            Future.delayed(Duration(milliseconds: 200), () {
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => RequestServiceFlow(
                    username: state.user.displayName ?? 'User',
                  ),
                ),
                (route) => false,
              );
            });
          });
        } else if (state is AuthTermsNotAccepted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Anda harus menyetujui Ketentuan Layanan dan Kebijakan Privasi terlebih dahulu'),
            ),
          );
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.1),
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(51),
                                offset: const Offset(0, 15),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/app-logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.04),
                        Text(
                          "Punya Masalah\nDengan Perangkatmu?",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Silahkan masuk untuk melanjutkan",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Google Sign In Button
                        InkWell(
                          onTap: _isGoogleLoading ? null : _handleGoogleSignIn,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isGoogleLoading)
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.grey.shade400),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: SvgPicture.asset(
                                      'assets/svg/login/google.svg',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    _isGoogleLoading
                                        ? 'Sedang Masuk...'
                                        : 'Masuk dengan Google',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Phone Number Sign In Button
                        InkWell(
                          onTap: _isWhatsappLoading
                              ? null
                              : () {
                                  if (!_isChecked) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Anda harus menyetujui Ketentuan Layanan dan Kebijakan Privasi terlebih dahulu'),
                                      ),
                                    );
                                    return;
                                  }
                                  // Implement Phone Sign In
                                },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: SvgPicture.asset(
                                    'assets/svg/login/whatsapp_login.svg',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    'Masuk dengan No. WA/HP',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, state) {
                                return Checkbox(
                                  value: _isChecked,
                                  onChanged: (value) {
                                    setState(() => _isChecked = value ?? false);
                                    context
                                        .read<AuthBloc>()
                                        .add(AuthTermsAccepted(value ?? false));
                                  },
                                );
                              },
                            ),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                  children: [
                                    TextSpan(
                                        text:
                                            'Saya telah membaca dan menyetujui '),
                                    TextSpan(
                                      text: 'Ketentuan Layanan',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                    TextSpan(text: ' dan '),
                                    TextSpan(
                                      text: 'Kebijakan Privasi',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                    TextSpan(text: ' Service HP Online'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Tambahkan tombol login admin di bagian bawah
                        TextButton(
                          onPressed: () => _showAdminLoginDialog(),
                          child: Text(
                            'Login sebagai Admin',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
