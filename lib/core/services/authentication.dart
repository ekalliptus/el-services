import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Authentication {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) return null;

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      print(
          'Successfully signed in with Google: ${userCredential.user?.displayName}');
      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      print('Starting complete logout process...');

      // 1. Hapus HANYA data sesi dari SharedPreferences.
      // Jangan pakai prefs.clear() karena itu menghapus preferensi durable
      // (mis. flag onboarding, info versi update) yang tidak terkait sesi.
      final prefs = await SharedPreferences.getInstance();
      const sessionKeys = [
        'admin_logged_in',
        'admin_session',
        'profile_complete',
        'admin_filter_start_date',
        'admin_filter_end_date',
        'admin_sort_field',
        'admin_sort_ascending',
      ];
      for (final key in sessionKeys) {
        await prefs.remove(key);
      }
      print('Session keys cleared from SharedPreferences');

      // 2. Jika menggunakan Supabase, logout dari Supabase
      try {
        final supabase = Supabase.instance.client;
        await supabase.auth.signOut();
        print('Supabase signOut completed');
      } catch (e) {
        print('Error signing out from Supabase: $e');
        // Lanjutkan proses logout meskipun ada error
      }

      // 3. Revoke akses dari Google Sign In
      try {
        await _googleSignIn.disconnect();
        print('Google Sign In disconnected');
      } catch (e) {
        print('Error disconnecting Google Sign In: $e');
        // Lanjutkan proses logout meskipun ada error
      }

      // 4. Hapus data pengguna dari Firebase Auth
      await _auth.signOut();
      print('Firebase Auth signOut completed');

      // 5. Muat ulang halaman untuk memastikan semua state direset
      // Reset auth cache di Firebase
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.NONE);
        print('Firebase persistence reset to NONE');
      } catch (e) {
        print('Error resetting Firebase persistence: $e');
      }

      print('Complete logout process finished successfully');
    } catch (e) {
      print('Error during complete logout: $e');
      // Masih coba signOut dari yang penting meskipun error
      await _auth.signOut();
      await _googleSignIn.signOut();
      throw Exception('Gagal logout: $e');
    }
  }
}
