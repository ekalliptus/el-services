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

      // 1. Hapus data sesi dari SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Hapus semua data
      print('SharedPreferences cleared');

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
