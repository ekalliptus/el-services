import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://dovyanobuzawvgpwvzgn.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRvdnlhbm9idXphd3ZncHd2emduIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzgwOTU0NjcsImV4cCI6MjA1MzY3MTQ2N30.ZdqMXBCe-XTX5sbWXzfGL23A88jSvsMhpHC5yOuqt7M';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
