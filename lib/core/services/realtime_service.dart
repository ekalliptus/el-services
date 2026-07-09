import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService {
  final _supabase = Supabase.instance.client;
  final _streamController = StreamController<Map<String, dynamic>>.broadcast();
  List<RealtimeChannel> _activeChannels = [];

  Stream<Map<String, dynamic>> get stream => _streamController.stream;

  /// Menambahkan event ke stream hanya bila controller belum ditutup,
  /// mencegah StateError bila callback realtime datang setelah dispose().
  void _safeAdd(Map<String, dynamic> event) {
    if (!_streamController.isClosed) {
      _streamController.add(event);
    }
  }

  Future<void> setupRealtimeSubscriptions() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    // Hapus channel yang ada dari client (bukan sekadar unsubscribe) agar
    // tidak ada langganan duplikat saat setup dipanggil ulang.
    for (var channel in _activeChannels) {
      await _supabase.removeChannel(channel);
    }
    _activeChannels.clear();

    // Subscribe ke perubahan services
    final servicesChannel = _supabase
        .channel('services')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'services',
          callback: (payload) {
            print('Service change detected:');
            print('Old record: ${payload.oldRecord}');
            print('New record: ${payload.newRecord}');

            // Kirim update hanya jika status berubah.
            // Catatan: oldRecord hanya terisi penuh bila tabel services diset
            // REPLICA IDENTITY FULL; jika tidak, oldRecord['status'] bernilai
            // null dan kondisi ini selalu terpenuhi (lihat SECURITY-PAYMENT.md).
            if (payload.oldRecord['status'] != payload.newRecord['status']) {
              _safeAdd({
                'type': 'service_update',
                'data': payload.newRecord,
                'old_data': payload.oldRecord,
                'event': payload.eventType,
                'table': 'services',
              });
            }
          },
        )
        .subscribe();

    _activeChannels.add(servicesChannel);

    // Subscribe ke perubahan testimonials
    final testimonialsChannel = _supabase
        .channel('testimonials')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'testimonials',
          callback: (payload) {
            _safeAdd({
              'type': 'testimonial_update',
              'data': payload.newRecord,
              'event': payload.eventType,
              'table': 'testimonials',
            });
          },
        )
        .subscribe();

    _activeChannels.add(testimonialsChannel);

    // Subscribe ke perubahan complaints
    final complaintsChannel = _supabase
        .channel('complaints')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'complaints',
          callback: (payload) {
            _safeAdd({
              'type': 'complaint_update',
              'data': payload.newRecord,
              'event': payload.eventType,
              'table': 'complaints',
            });
          },
        )
        .subscribe();

    _activeChannels.add(complaintsChannel);

    print(
        'Realtime subscriptions setup completed for ${_activeChannels.length} channels');
  }

  Future<void> dispose() async {
    // Hapus semua channel dari client terlebih dahulu (dan tunggu selesai)
    // agar tidak ada callback yang menembak controller setelah ditutup.
    for (var channel in _activeChannels) {
      await _supabase.removeChannel(channel);
    }
    _activeChannels.clear();
    if (!_streamController.isClosed) {
      await _streamController.close();
    }
  }
}
