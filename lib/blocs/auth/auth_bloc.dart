import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servicehponline/blocs/auth/auth_event.dart';
import 'package:servicehponline/blocs/auth/auth_state.dart';
import 'package:servicehponline/core/services/supabase_auth_bridge.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _termsAccepted = false;
  static const String TERMS_ACCEPTED_KEY = 'terms_accepted';

  late final StreamSubscription<User?> _authSub;

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthLoginSuccess>(_onAuthLoginSuccess);
    on<AuthTermsAccepted>(_onAuthTermsAccepted);

    // Load terms acceptance status when bloc is created
    _loadTermsAcceptance();

    // Subscribe to auth state changes
    _authSub = _auth.authStateChanges().listen((User? user) {
      print('Auth state changed - User: ${user?.displayName}');
      // Sinkronkan sesi Supabase (untuk RLS per-user) mengikuti status
      // Firebase. Fire-and-forget; kegagalan tidak memblokir UI.
      SupabaseAuthBridge.sync();
      if (!isClosed && user != null && _termsAccepted) {
        add(AuthLoginSuccess(user));
      }
    });
  }

  @override
  Future<void> close() {
    _authSub.cancel();
    return super.close();
  }

  Future<void> _loadTermsAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    _termsAccepted = prefs.getBool(TERMS_ACCEPTED_KEY) ?? false;
  }

  Future<void> _saveTermsAcceptance(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(TERMS_ACCEPTED_KEY, accepted);
  }

  void _onAuthCheckRequested(
      AuthCheckRequested event, Emitter<AuthState> emit) async {
    try {
      emit(AuthLoading());
      await _loadTermsAcceptance();
      final currentUser = _auth.currentUser;
      if (currentUser != null && _termsAccepted) {
        print('Current user found: ${currentUser.displayName}');
        // Pastikan sesi Supabase siap sebelum halaman membaca data ber-RLS.
        await SupabaseAuthBridge.sync();
        emit(AuthAuthenticated(currentUser));
      } else {
        print('No current user found or terms not accepted');
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      print('Error checking auth state: $e');
      emit(AuthFailure(e.toString()));
    }
  }

  void _onAuthLogoutRequested(
      AuthLogoutRequested event, Emitter<AuthState> emit) async {
    try {
      emit(AuthLoading());
      await _auth.signOut();
      await _saveTermsAcceptance(false);
      _termsAccepted = false;
      emit(AuthUnauthenticated());
    } catch (e) {
      print('Error signing out: $e');
      emit(AuthFailure(e.toString()));
    }
  }

  void _onAuthLoginSuccess(
      AuthLoginSuccess event, Emitter<AuthState> emit) async {
    try {
      if (!_termsAccepted) {
        print('Terms not accepted');
        emit(AuthTermsNotAccepted());
        return;
      }
      print('Login success for user: ${event.user.displayName}');
      // Siapkan sesi Supabase (RLS per-user) sebelum masuk ke area data.
      await SupabaseAuthBridge.sync();
      emit(AuthAuthenticated(event.user));
    } catch (e) {
      print('Error handling login success: $e');
      emit(AuthFailure(e.toString()));
    }
  }

  void _onAuthTermsAccepted(
      AuthTermsAccepted event, Emitter<AuthState> emit) async {
    try {
      _termsAccepted = event.accepted;
      await _saveTermsAcceptance(_termsAccepted);
      print('Terms accepted: $_termsAccepted');
      final currentUser = _auth.currentUser;
      if (_termsAccepted && currentUser != null) {
        emit(AuthAuthenticated(currentUser));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      print('Error handling terms acceptance: $e');
      emit(AuthFailure(e.toString()));
    }
  }
}
