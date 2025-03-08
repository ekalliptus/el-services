// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:servicehponline/blocs/auth/auth_bloc.dart';
import 'package:servicehponline/blocs/auth/auth_event.dart';
import 'package:servicehponline/blocs/auth/auth_state.dart';
import 'package:servicehponline/features/auth/pages/login_page.dart';
import 'package:servicehponline/features/auth/pages/onboarding_page.dart';
import 'package:servicehponline/features/user/widgets/request_service_flow_widget.dart';
import 'package:servicehponline/features/user/pages/service_history_page.dart';
import 'package:servicehponline/features/admin/admin_dashboard.dart';
import 'package:servicehponline/core/constants/constants.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:servicehponline/core/services/supabase_config.dart';
import 'package:provider/provider.dart';
import 'package:servicehponline/core/services/realtime_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servicehponline/features/profile/pages/profile_setup_page.dart';

// Flag untuk menentukan apakah user sudah melalui onboarding
bool hasCompletedOnboarding = false;

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    await dotenv.load(fileName: ".env");

    // Inisialisasi Supabase
    print('Initializing Supabase...');
    await SupabaseConfig.initialize();
    print('Supabase initialized successfully');

    // Periksa apakah user sudah melalui onboarding
    final prefs = await SharedPreferences.getInstance();
    hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;

    runApp(const MyApp());
  } catch (e) {
    print('Error initializing app: $e');
    // Tampilkan error ke user atau handle sesuai kebutuhan
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc()..add(AuthCheckRequested()),
        ),
        Provider<RealtimeService>(
          create: (_) => RealtimeService(),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'Service HP Online',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Constants.primaryColor),
            titleTextStyle: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            centerTitle: false,
            toolbarHeight: 60,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            labelStyle: TextStyle(color: Colors.black54),
            prefixIconColor: Colors.black54,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Constants.primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red),
            ),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  // Jika user sudah terautentikasi
                  if (state is AuthAuthenticated) {
                    // Cek apakah user sudah melewati onboarding
                    if (!hasCompletedOnboarding) {
                      return const OnboardingPage();
                    }

                    // Cek apakah profile sudah lengkap
                    final prefs = SharedPreferences.getInstance();
                    prefs.then((pref) {
                      bool isProfileComplete =
                          pref.getBool('profile_complete') ?? false;
                      if (!isProfileComplete) {
                        // Arahkan ke halaman setup profil
                        Future.microtask(() {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ProfileSetupPage(isFirstTime: true),
                            ),
                          );
                        });
                      }
                    });

                    return RequestServiceFlow(
                        username: state.user.displayName ?? '');
                  }

                  // Jika belum login, arahkan ke halaman login
                  return const Home();
                },
              ),
          '/history': (context) => const ServiceHistoryPage(),
          '/admin': (context) => const AdminDashboard(),
          '/onboarding': (context) => const OnboardingPage(),
          '/profile_setup': (context) =>
              const ProfileSetupPage(isFirstTime: true),
        },
      ),
    );
  }
}
