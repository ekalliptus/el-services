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
  bool _isLoading = false;
  bool _isAdminLoading = false;

  // Controller untuk form login admin
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

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

    setState(() => _isLoading = true);

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
        setState(() => _isLoading = false);
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
                          // Login dengan Supabase
                          final response =
                              await _supabase.auth.signInWithPassword(
                            email: _adminEmailController.text.trim(),
                            password: _adminPasswordController.text,
                          );

                          if (!mounted) return;

                          if (response.user != null) {
                            try {
                              // Cek role admin di profiles
                              final userData = await _supabase
                                  .from('profiles')
                                  .select()
                                  .match({'id': response.user!.id}).single();

                              if (userData['role'] == 'admin') {
                                Navigator.of(context).pop();
                                Navigator.pushReplacementNamed(
                                    context, '/admin');
                              } else {
                                // Jika bukan admin, logout dan tampilkan pesan error
                                await _supabase.auth.signOut();
                                throw Exception('Akses ditolak: Bukan admin');
                              }
                            } catch (e) {
                              print('Error checking admin role: $e');
                              // Logout jika gagal mengecek role
                              await _supabase.auth.signOut();
                              throw Exception(
                                  'Gagal memverifikasi akses admin');
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
                          } else if (e.toString().contains('Akses ditolak')) {
                            errorMessage = 'Anda tidak memiliki akses admin';
                          } else if (e.toString().contains('network')) {
                            errorMessage = 'Gagal terhubung ke server';
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
          print('User authenticated, navigating to RequestServiceFlow');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => RequestServiceFlow(
                username: state.user.displayName ?? 'User',
              ),
            ),
            (route) => false,
          );
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
                          onTap: _isLoading ? null : _handleGoogleSignIn,
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
                                if (_isLoading)
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
                                    _isLoading
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
                          onTap: () {
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
