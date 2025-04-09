// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:servicehponline/blocs/auth/auth_bloc.dart';
import 'package:servicehponline/blocs/auth/auth_event.dart';
import 'package:servicehponline/blocs/auth/auth_state.dart';
import 'package:servicehponline/features/auth/pages/login_page.dart';
import 'package:servicehponline/features/auth/pages/onboarding_page.dart';
import 'package:servicehponline/features/user/widgets/request_service_flow_widget.dart';
import 'package:servicehponline/features/user/pages/service_history_page.dart';
import 'package:servicehponline/features/admin/admin_dashboard.dart';
import 'package:servicehponline/features/admin/pages/super_admin_dashboard.dart';
import 'package:servicehponline/core/constants/constants.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:servicehponline/core/services/supabase_config.dart';
import 'package:provider/provider.dart';
import 'package:servicehponline/core/services/realtime_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servicehponline/features/profile/pages/profile_setup_page.dart';
import 'package:servicehponline/core/services/update_service.dart';
import 'package:servicehponline/features/maintenance/maintenance_service.dart';
import 'package:servicehponline/features/maintenance/maintenance_page.dart';

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

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Future untuk memeriksa maintenance mode
  late Future<bool> _maintenanceCheckFuture;

  @override
  void initState() {
    super.initState();
    _maintenanceCheckFuture = _checkMaintenanceMode();
  }

  // Fungsi untuk memeriksa apakah aplikasi dalam maintenance mode
  Future<bool> _checkMaintenanceMode() async {
    try {
      return await MaintenanceService.isInMaintenanceMode();
    } catch (e) {
      print('Error memeriksa maintenance mode: $e');
      return false;
    }
  }

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
        Provider<UpdateService>(
          create: (_) => UpdateService(),
        ),
      ],
      child: MaterialApp(
        title: 'Service HP Online',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          const Locale('id', 'ID'),
          const Locale('en', 'US'),
        ],
        locale: const Locale('id', 'ID'),
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
          '/': (context) {
            // Periksa pembaruan aplikasi setiap kali aplikasi berjalan
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkForAppUpdates(context);
            });

            // Periksa apakah aplikasi dalam maintenance mode
            return FutureBuilder<bool>(
              future: _maintenanceCheckFuture,
              builder: (context, maintenanceSnapshot) {
                // Tampilkan loading saat memeriksa maintenance mode
                if (maintenanceSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                // Jika aplikasi dalam maintenance mode, tampilkan halaman maintenance
                if (maintenanceSnapshot.data == true) {
                  return FutureBuilder<Map<String, dynamic>>(
                    future: MaintenanceService.getMaintenanceDetails(),
                    builder: (context, detailsSnapshot) {
                      if (detailsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final details = detailsSnapshot.data ??
                          {
                            'title': 'Aplikasi Sedang Maintenance',
                            'message':
                                'Kami sedang melakukan perbaikan sistem untuk meningkatkan layanan. Silakan kembali lagi nanti.',
                            'estimatedCompletion': null,
                          };

                      return MaintenancePage(
                        title: details['title'],
                        message: details['message'],
                        estimatedCompletion: details['estimatedCompletion'],
                      );
                    },
                  );
                }

                // Jika tidak dalam maintenance mode, tampilkan aplikasi normal
                return BlocBuilder<AuthBloc, AuthState>(
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
                );
              },
            );
          },
          '/history': (context) => const ServiceHistoryPage(),
          '/admin': (context) => const AdminDashboard(),
          '/super_admin': (context) => const SuperAdminDashboard(),
          '/onboarding': (context) => const OnboardingPage(),
          '/profile_setup': (context) =>
              const ProfileSetupPage(isFirstTime: true),
        },
      ),
    );
  }

  // Fungsi untuk memeriksa pembaruan aplikasi
  void _checkForAppUpdates(BuildContext context) async {
    // Dapatkan layanan pembaruan dari provider
    final updateService = Provider.of<UpdateService>(context, listen: false);

    try {
      // Periksa apakah sudah waktunya untuk memeriksa pembaruan
      bool shouldCheck = await updateService.shouldCheckForUpdates();
      if (!shouldCheck) {
        print('Belum waktunya memeriksa pembaruan. Melewati...');
        return;
      }

      // Periksa pembaruan aplikasi
      final updateInfo = await updateService.checkAppVersion();

      // Jika ada pembaruan tersedia, tampilkan notifikasi pembaruan yang optimal
      if (updateInfo != null) {
        // Jalankan di microtask agar tidak mengganggu proses rendering
        Future.microtask(() {
          updateService.showOptimalUpdateNotification(context, updateInfo);
        });
      }
    } catch (e) {
      print('Error saat memeriksa pembaruan: $e');
    }
  }
}
