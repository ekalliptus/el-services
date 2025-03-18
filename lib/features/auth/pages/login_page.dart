import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:servicehponline/blocs/auth/auth_bloc.dart';
import 'package:servicehponline/blocs/auth/auth_event.dart';
import 'package:servicehponline/blocs/auth/auth_state.dart';
import 'package:servicehponline/core/services/authentication.dart';
import 'package:servicehponline/features/user/widgets/request_service_flow_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servicehponline/features/auth/pages/onboarding_page.dart';
import 'package:servicehponline/features/profile/pages/profile_setup_page.dart';

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
  final _supabase = supabase.Supabase.instance.client;
  bool _isChecked = false;
  bool _isGoogleLoading = false;
  bool _isWhatsappLoading = false;
  bool _isAdminLoading = false;

  // Controller untuk form login admin
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
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

                              if (adminCheck != null &&
                                  adminCheck['role'] == 'admin') {
                                print(
                                    'Verifikasi admin berhasil. Mengarahkan ke halaman admin.');

                                // Simpan sesi admin
                                final session = response.session;
                                if (session != null) {
                                  await _saveAdminSession(session);
                                }

                                Navigator.of(context).pop();
                                Navigator.pushReplacementNamed(
                                    context, '/admin');
                              } else {
                                // Bukan admin, lakukan logout
                                print('Bukan admin, melakukan logout');
                                await _supabase.auth.signOut();

                                String errorMessage = adminCheck == null
                                    ? 'Akun ini tidak terdaftar sebagai admin.'
                                    : 'Akun ini tidak memiliki hak akses admin.';

                                throw Exception(errorMessage);
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
  Future<void> _saveAdminSession(supabase.Session session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('admin_logged_in', true);

      // Simpan data sesi
      final sessionData = {
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken,
        'expires_in': session.expiresIn,
        'provider_token': session.providerToken,
        'provider_refresh_token': session.providerRefreshToken,
        'user': {
          'id': session.user.id,
          'email': session.user.email,
        }
      };

      await prefs.setString('admin_session', jsonEncode(sessionData));
      print('Admin session saved successfully');
    } catch (e) {
      print('Error saving admin session: $e');
    }
  }

  // Cek apakah sudah ada sesi admin yang tersimpan
  Future<void> _checkExistingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAdminLoggedIn = prefs.getBool('admin_logged_in') ?? false;
      final adminSessionStr = prefs.getString('admin_session');

      if (isAdminLoggedIn && adminSessionStr != null) {
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

                if (adminCheck != null && adminCheck['role'] == 'admin') {
                  print('Admin session refreshed and verified successfully');
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/admin');
                    return;
                  }
                }
              }
            } catch (e) {
              print('Error refreshing session: $e');
            }
          }

          // Jika refresh gagal, coba set session dengan access token
          await _supabase.auth.setSession(sessionData['access_token']);

          // Verifikasi sesi
          final currentSession = await _supabase.auth.currentSession;
          if (currentSession != null) {
            // Verifikasi bahwa user masih admin
            final adminCheck = await _supabase
                .from('admins')
                .select('*')
                .eq('id', currentSession.user.id)
                .maybeSingle();

            if (adminCheck != null && adminCheck['role'] == 'admin') {
              print('Admin session restored successfully');
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/admin');
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('admin_logged_in');
      await prefs.remove('admin_session');
      await _supabase.auth.signOut();
      print('Admin session cleared successfully');
    } catch (e) {
      print('Error clearing admin session: $e');
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
            final supabaseClient = supabase.Supabase.instance.client;

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

                // Cek kelengkapan profil berdasarkan data Supabase
                bool isProfileComplete = profileData['fullname'] != null &&
                    profileData['phoneNumber'] != null &&
                    profileData['address'] != null;

                print(
                    'Status kelengkapan profil (isProfileComplete): $isProfileComplete');
                print('Detail pengecekan:');
                print('fullname: ${profileData['fullname']}');
                print('phoneNumber: ${profileData['phoneNumber']}');
                print('address: ${profileData['address']}');

                // Update flag
                prefs.setBool('profile_complete', isProfileComplete);

                if (isProfileComplete) {
                  print('PROFIL LENGKAP - mengarahkan ke halaman utama');
                  // Jika sudah lengkap, arahkan ke halaman utama
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => RequestServiceFlow(
                        username: profileData['fullname'] ??
                            state.user.displayName ??
                            'User',
                      ),
                    ),
                    (route) => false,
                  );
                } else {
                  print(
                      'PROFIL TIDAK LENGKAP - mengarahkan ke pengaturan profil');
                  // Jika belum lengkap, arahkan ke setup profil
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) =>
                          const ProfileSetupPage(isFirstTime: false),
                    ),
                    (route) => false,
                  );
                }
              } else {
                print('PROFIL TIDAK DITEMUKAN di Supabase');
                // Cek apakah pengguna sudah pernah onboarding
                bool hasCompletedOnboarding =
                    prefs.getBool('has_completed_onboarding') ?? false;

                if (!hasCompletedOnboarding) {
                  print(
                      'ONBOARDING BELUM SELESAI - mengarahkan ke halaman onboarding');
                  // Jika belum onboarding, arahkan ke halaman onboarding
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const OnboardingPage()),
                    (route) => false,
                  );
                } else {
                  print(
                      'ONBOARDING SUDAH SELESAI, TAPI TIDAK ADA PROFIL - mengarahkan ke pengaturan profil');
                  // Arahkan ke halaman pengaturan profil untuk membuat profil baru
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) =>
                          const ProfileSetupPage(isFirstTime: true),
                    ),
                    (route) => false,
                  );
                }
              }
            }).catchError((e) {
              print('ERROR memeriksa profil di Supabase: $e');

              // Jika gagal memeriksa profil, gunakan fallback ke flow onboarding normal
              bool hasCompletedOnboarding =
                  prefs.getBool('has_completed_onboarding') ?? false;

              if (!hasCompletedOnboarding) {
                print(
                    'FALLBACK: ONBOARDING BELUM SELESAI - mengarahkan ke halaman onboarding');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) => const OnboardingPage()),
                  (route) => false,
                );
              } else {
                print(
                    'FALLBACK: ONBOARDING SUDAH SELESAI - mengarahkan ke pengaturan profil');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) =>
                        const ProfileSetupPage(isFirstTime: true),
                  ),
                  (route) => false,
                );
              }
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
