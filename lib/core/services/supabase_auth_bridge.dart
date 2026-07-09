import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:servicehponline/core/services/supabase_config.dart';

/// Menyinkronkan sesi Supabase dengan status login Firebase.
///
/// User biasa login via Firebase, tetapi data disimpan di Supabase. Agar RLS
/// bisa memfilter per-user (menutup IDOR), client memerlukan sesi Supabase
/// yang membawa firebase_uid. Fungsi Edge `firebase-bridge` menerbitkan
/// access token Supabase dari Firebase ID token; di sini token itu dipasang.
class SupabaseAuthBridge {
  SupabaseAuthBridge._();

  static final _bridgeUrl =
      '${SupabaseConfig.supabaseUrl}/functions/v1/firebase-bridge';

  /// Pastikan ada sesi Supabase yang valid untuk user Firebase saat ini.
  /// Aman dipanggil berkali-kali (idempoten). Bila tidak ada user Firebase,
  /// sesi Supabase dibersihkan.
  static Future<void> sync() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final supabase = SupabaseConfig.client;

    if (firebaseUser == null) {
      if (supabase.auth.currentSession != null) {
        await supabase.auth.signOut();
      }
      return;
    }

    // Sudah punya sesi yang belum kedaluwarsa untuk uid ini → lewati.
    final existing = supabase.auth.currentSession;
    if (existing != null &&
        !_isExpiringSoon(existing) &&
        supabase.auth.currentUser?.userMetadata?['firebase_uid'] ==
            firebaseUser.uid) {
      return;
    }

    final idToken = await firebaseUser.getIdToken();
    if (idToken == null) return;

    final res = await http.post(
      Uri.parse(_bridgeUrl),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.supabaseAnonKey,
      },
    );

    if (res.statusCode != 200) {
      // Jangan blokir alur user; RLS akan menolak baca lintas-user, dan
      // fitur yang butuh sesi akan gagal terkontrol.
      // ignore: avoid_print
      print('SupabaseAuthBridge gagal: ${res.statusCode} ${res.body}');
      return;
    }

    final token = (jsonDecode(res.body) as Map)['access_token'] as String?;
    if (token != null) {
      await supabase.auth.setSession(token);
    }
  }

  static bool _isExpiringSoon(Session s) {
    final exp = s.expiresAt;
    if (exp == null) return true;
    final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return expiry.difference(DateTime.now()).inMinutes < 5;
  }
}
