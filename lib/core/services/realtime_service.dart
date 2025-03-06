import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService {
  final _supabase = Supabase.instance.client;
  final _streamController = StreamController<Map<String, dynamic>>.broadcast();
  List<RealtimeChannel> _activeChannels = [];

  Stream<Map<String, dynamic>> get stream => _streamController.stream;

  void setupRealtimeSubscriptions() {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    // Unsubscribe dari channel yang ada
    for (var channel in _activeChannels) {
      channel.unsubscribe();
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

            // Kirim update hanya jika status berubah
            if (payload.oldRecord['status'] != payload.newRecord['status']) {
              _streamController.add({
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
            _streamController.add({
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
            _streamController.add({
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

  void dispose() {
    // Unsubscribe dari semua channel
    for (var channel in _activeChannels) {
      channel.unsubscribe();
    }
    _activeChannels.clear();
    _streamController.close();
  }
}
