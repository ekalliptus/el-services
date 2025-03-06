import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final _supabase = Supabase.instance.client;

  Future<void> initNotifications() async {
    try {
      // Reset dan inisialisasi channel
      print('Initializing notification channels...');
      await AwesomeNotifications().initialize(
        'resource://drawable/ic_notification',
        [
          NotificationChannel(
            channelKey: 'basic_channel',
            channelName: 'Basic Notifications',
            channelDescription: 'Notification channel for basic notifications',
            defaultColor: const Color(0xFF2196F3),
            ledColor: Colors.white,
            importance: NotificationImportance.High,
            channelShowBadge: true,
            enableVibration: true,
            enableLights: true,
            playSound: true,
            soundSource: 'resource://raw/notification_sound',
          ),
          NotificationChannel(
            channelKey: 'service_status_channel',
            channelName: 'Service Status',
            channelDescription: 'Notifications for service status updates',
            defaultColor: const Color(0xFF2196F3),
            ledColor: Colors.white,
            importance: NotificationImportance.High,
            channelShowBadge: true,
            enableVibration: true,
            enableLights: true,
            playSound: true,
            soundSource: 'resource://raw/notification_sound',
            onlyAlertOnce: false,
          ),
        ],
      );

      // Set up listeners untuk menangani aksi notifikasi
      await AwesomeNotifications().setListeners(
        onActionReceivedMethod: onActionReceivedMethod,
        onNotificationCreatedMethod: onNotificationCreatedMethod,
        onNotificationDisplayedMethod: onNotificationDisplayedMethod,
        onDismissActionReceivedMethod: onDismissActionReceivedMethod,
      );

      // Setup Supabase realtime subscription untuk status service
      await _setupServiceStatusSubscription();

      print('Notification service initialized successfully');
    } catch (e, stackTrace) {
      print('Error initializing notification service: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _setupServiceStatusSubscription() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      print('User tidak login, tidak bisa setup notifikasi');
      return;
    }

    print('Setting up service status subscription for user: ${currentUser.id}');

    try {
      // Unsubscribe dari channel yang ada (jika ada)
      await _supabase.channel('services').unsubscribe();
      
      final channel = _supabase
          .channel('services')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'services',
            callback: (payload) async {
              print('=== NOTIFICATION DEBUG ===');
              print('Received payload: ${payload.newRecord}');
              print('Old status: ${payload.oldRecord['status']}');
              print('New status: ${payload.newRecord['status']}');
              print('User ID: ${payload.newRecord['user_id']}');
              print('Current user ID: ${currentUser.id}');
              print('========================');

              try {
                final serviceId = payload.newRecord['id'];
                final newStatus = payload.newRecord['status'];
                final oldStatus = payload.oldRecord['status'];
                final userId = payload.newRecord['user_id'];

                // Verifikasi bahwa service ini milik user yang sedang login
                if (userId != currentUser.id) {
                  print('Service bukan milik user yang sedang login');
                  return;
                }

                print('Processing status change for service #$serviceId: $oldStatus -> $newStatus');

                if (newStatus == oldStatus) {
                  print('Status tidak berubah: $oldStatus -> $newStatus');
                  return;
                }

                String statusMessage = '';
                switch (newStatus.toString().toUpperCase()) {
                  case 'PENDING':
                    statusMessage = 'Permintaan service Anda sedang diproses';
                    break;
                  case 'CONFIRMED':
                    statusMessage = 'Service Anda telah dikonfirmasi';
                    break;
                  case 'IN_PROGRESS':
                    statusMessage = 'Service Anda sedang dikerjakan';
                    break;
                  case 'COMPLETED':
                    statusMessage = 'Service Anda telah selesai';
                    break;
                  case 'CANCELLED':
                    statusMessage = 'Service Anda telah dibatalkan';
                    break;
                  case 'WAITING_PAYMENT':
                    statusMessage = 'Menunggu pembayaran Anda';
                    break;
                  case 'PROCESSED':
                    statusMessage = 'Service Anda sedang diproses';
                    break;
                  default:
                    statusMessage = 'Status service Anda telah diperbarui';
                }

                print('Attempting to show notification with message: $statusMessage');

                // Buat ID unik untuk notifikasi
                final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;
                print('Generated notification ID: $notificationId');

                bool success = await AwesomeNotifications().createNotification(
                  content: NotificationContent(
                    id: notificationId,
                    channelKey: 'service_status_channel',
                    title: 'Update Status Service #$serviceId',
                    body: statusMessage,
                    payload: {
                      'type': 'service_status',
                      'service_id': serviceId.toString(),
                      'status': newStatus,
                      'user_id': userId,
                    },
                    notificationLayout: NotificationLayout.Default,
                  ),
                );

                print('Notification ${success ? 'sent successfully' : 'failed to send'} with ID: $notificationId');
              } catch (e, stackTrace) {
                print('Error processing service update: $e');
                print('Stack trace: $stackTrace');
              }
            },
          );

      final response = await channel.subscribe();
      print('Channel subscription response: $response');

      if (response == 'SUBSCRIBED') {
        print('Successfully subscribed to service updates');
      } else {
        print('Failed to subscribe to service updates: $response');
      }
    } catch (e, stackTrace) {
      print('Error setting up subscription: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Use this method to detect when a new notification or a schedule is created
  @pragma('vm:entry-point')
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {
    print('Notification created: ${receivedNotification.toMap()}');
  }

  /// Use this method to detect every time that a new notification is displayed
  @pragma('vm:entry-point')
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {
    print('Notification displayed: ${receivedNotification.toMap()}');
  }

  /// Use this method to detect if the user dismissed a notification
  @pragma('vm:entry-point')
  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {
    print('Notification dismissed: ${receivedAction.toMap()}');
  }

  /// Use this method to detect when the user taps on a notification or action button
  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    print('Notification action clicked: ${receivedAction.toMap()}');

    // Disini Anda bisa menambahkan logika untuk menangani klik notifikasi
    // Contoh: Navigasi ke halaman tertentu berdasarkan payload
    if (receivedAction.payload?['type'] == 'order') {
      // Navigasi ke halaman detail order
      print('Navigate to order detail: ${receivedAction.payload?['id']}');
    }
  }

  // Fungsi untuk mengirim notifikasi lokal
  Future<bool> showLocalNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
  }) async {
    try {
      return await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: payload?['type'] == 'service_status'
              ? 'service_status_channel'
              : 'basic_channel',
          title: title,
          body: body,
          payload: payload,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Status,
        ),
      );
    } catch (e) {
      print('Error showing notification: $e');
      return false;
    }
  }

  // Fungsi untuk menjadwalkan notifikasi
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduleDate,
    Map<String, String>? payload,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'scheduled_channel',
        title: title,
        body: body,
        payload: payload,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar.fromDate(date: scheduleDate),
    );
  }

  // Fungsi untuk membatalkan semua notifikasi
  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }
}
