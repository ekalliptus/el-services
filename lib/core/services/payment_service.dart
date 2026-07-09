import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:servicehponline/data/models/service_model.dart';
import 'package:servicehponline/core/services/supabase_config.dart';
import 'package:servicehponline/core/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

class PaymentService {
  late final SupabaseClient _supabase;
  final StorageService _storageService = StorageService();
  final firebase.FirebaseAuth _firebaseAuth = firebase.FirebaseAuth.instance;
  final String _baseUrl = 'https://api.servicehponline.com'; // URL API backend

  // Endpoint Edge Function pembayaran (secret Xendit hanya di server).
  String get _createInvoiceUrl =>
      '${SupabaseConfig.supabaseUrl}/functions/v1/create-invoice';

  PaymentService() {
    try {
      _supabase = Supabase.instance.client;
    } catch (e) {
      throw Exception('Supabase belum diinisialisasi. Error: $e');
    }
  }

  // Membuat permintaan service baru tanpa pembayaran
  Future<Map<String, dynamic>> createServiceRequest(
      ServiceModel service) async {
    try {
      // 0. Periksa status autentikasi Firebase
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        throw Exception('User belum login');
      }

      // 1. Upload media jika ada
      String? damagePictureUrl;
      String? frontPictureUrl;
      String? backPictureUrl;
      String? videoUrl;

      if (service.pictureDamage != null) {
        damagePictureUrl = await _storageService.uploadImage(
          File(service.pictureDamage!),
          'temp',
        );
      }

      if (service.pictureFront != null) {
        frontPictureUrl = await _storageService.uploadImage(
          File(service.pictureFront!),
          'temp',
        );
      }

      if (service.pictureBack != null) {
        backPictureUrl = await _storageService.uploadImage(
          File(service.pictureBack!),
          'temp',
        );
      }

      if (service.video != null) {
        videoUrl = await _storageService.uploadVideo(
          File(service.video!),
          'temp',
        );
      }

      // 2. Simpan data service ke Supabase
      final Map<String, dynamic> serviceData = {
        'user_id': firebaseUser.uid,
        'fullname': service.fullname,
        'phoneNumber': service.phoneNumber,
        'address': service.address,
        'device': service.device,
        'problem': service.problem,
        'brand': service.brand,
        'model': service.model,
        'description': service.description,
        'shipping_method': service.shippingMethod,
        'latitude': service.latitude,
        'longitude': service.longitude,
        'status': 'PENDING',
        'service_cost': null, // Biaya service awalnya null
        'created_at': DateTime.now().toIso8601String(),
        'picture_damage_url': damagePictureUrl,
        'picture_front_url': frontPictureUrl,
        'picture_back_url': backPictureUrl,
        'video_url': videoUrl,
      };

      final response = await _supabase
          .from('services')
          .insert(serviceData)
          .select()
          .single();

      print('Service data saved to Supabase: $response');

      // 3. Update nama file media dengan ID yang benar jika ada
      final serviceId = response['id'];

      if (damagePictureUrl != null) {
        final newDamageUrl = await _storageService.uploadImage(
          File(service.pictureDamage!),
          serviceId,
        );
        await _storageService.deleteMedia(damagePictureUrl);

        if (newDamageUrl != null) {
          await _supabase
              .from('services')
              .update({'picture_damage_url': newDamageUrl}).eq('id', serviceId);
        }
      }

      if (frontPictureUrl != null) {
        final newFrontUrl = await _storageService.uploadImage(
          File(service.pictureFront!),
          serviceId,
        );
        await _storageService.deleteMedia(frontPictureUrl);

        if (newFrontUrl != null) {
          await _supabase
              .from('services')
              .update({'picture_front_url': newFrontUrl}).eq('id', serviceId);
        }
      }

      if (backPictureUrl != null) {
        final newBackUrl = await _storageService.uploadImage(
          File(service.pictureBack!),
          serviceId,
        );
        await _storageService.deleteMedia(backPictureUrl);

        if (newBackUrl != null) {
          await _supabase
              .from('services')
              .update({'picture_back_url': newBackUrl}).eq('id', serviceId);
        }
      }

      if (videoUrl != null) {
        final newVideoUrl = await _storageService.uploadVideo(
          File(service.video!),
          serviceId,
        );
        await _storageService.deleteMedia(videoUrl);

        if (newVideoUrl != null) {
          await _supabase
              .from('services')
              .update({'video_url': newVideoUrl}).eq('id', serviceId);
        }
      }

      return {'id': response['id'], 'status': 'PENDING'};
    } catch (e) {
      print('Error creating service request: $e');
      throw Exception('Gagal membuat permintaan service: $e');
    }
  }

  // Membuat pembayaran untuk service yang sudah ada
  Future<Map<String, dynamic>> createPayment(String serviceId) async {
    try {
      // Invoice dibuat oleh Edge Function (secret Xendit hanya di server).
      // Kirim Firebase ID token untuk otentikasi + verifikasi kepemilikan.
      final idToken = await _firebaseAuth.currentUser?.getIdToken();
      if (idToken == null) {
        throw Exception('User belum login');
      }

      final response = await http.post(
        Uri.parse(_createInvoiceUrl),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.supabaseAnonKey,
        },
        body: jsonEncode({'serviceId': serviceId}),
      );

      if (response.statusCode != 200) {
        final msg = _extractError(response.body);
        throw Exception('Gagal membuat pembayaran: $msg');
      }

      final data = jsonDecode(response.body);
      final invoiceUrl = data['invoice_url'];
      if (invoiceUrl == null) {
        throw Exception('Respons pembayaran tidak valid');
      }

      return {
        'id': serviceId,
        'paymentUrl': invoiceUrl,
      };
    } catch (e) {
      print('Error creating payment: $e');
      throw Exception('Gagal membuat pembayaran: $e');
    }
  }

  String _extractError(String body) {
    try {
      final j = jsonDecode(body);
      return (j is Map && j['error'] != null) ? j['error'].toString() : body;
    } catch (_) {
      return body;
    }
  }

  /// Status pembayaran adalah sumber-kebenaran server: hanya diperbarui oleh
  /// webhook Xendit. Client hanya MEMBACA kolom status; tidak boleh (dan
  /// tidak bisa, karena RLS) menuliskannya.
  Future<String> getPaymentStatus(String serviceId) async {
    try {
      final service = await _supabase
          .from('services')
          .select('status')
          .eq('id', serviceId)
          .single();

      return service['status'] ?? 'PENDING';
    } catch (e) {
      print('Error checking payment status: $e');
      return 'PENDING';
    }
  }

  /// Method untuk membuat pembayaran biaya tambahan
  Future<Map<String, dynamic>> createAdditionalPayment(
      String serviceId, String additionalCostId) async {
    try {
      // Dapatkan detail service dan biaya tambahan
      final service = await _supabase
          .from('services')
          .select('*')
          .eq('id', serviceId)
          .single();

      final additionalCost = await _supabase
          .from('additional_costs')
          .select('*')
          .eq('id', additionalCostId)
          .single();

      if (additionalCost['status'] != 'PENDING') {
        throw Exception('Biaya tambahan ini sudah dibayar atau tidak valid');
      }

      // Dapatkan detail customer
      final user = await _supabase
          .from('users')
          .select('*')
          .eq('firebase_uid', service['user_id'])
          .single();

      // Buat body request ke midtrans
      final Map<String, dynamic> transactionDetails = {
        'order_id':
            'ADD-${serviceId}-${additionalCostId}-${DateTime.now().millisecondsSinceEpoch}',
        'gross_amount': additionalCost['amount'],
      };

      final Map<String, dynamic> customerDetails = {
        'first_name': user['fullname'] ?? 'Customer',
        'email': user['email'] ?? service['email'],
        'phone': user['phone'] ?? service['phoneNumber'],
      };

      final List<Map<String, dynamic>> itemDetails = [
        {
          'id': 'ADDSVC-${additionalCostId}',
          'price': additionalCost['amount'],
          'quantity': 1,
          'name': 'Biaya Tambahan Service #${serviceId}',
          'category': 'Service',
          'merchant_name': 'Service HP Online',
        }
      ];

      // Gabungkan semua data
      final Map<String, dynamic> body = {
        'transaction_details': transactionDetails,
        'customer_details': customerDetails,
        'item_details': itemDetails,
      };

      // Lakukan request ke backend/midtrans untuk mendapatkan payment URL
      final response = await http.post(
        Uri.parse('$_baseUrl/create-payment'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception('Gagal membuat pembayaran: ${response.body}');
      }

      // Update status di database
      await _supabase.from('additional_costs').update({
        'payment_id': transactionDetails['order_id'],
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', additionalCostId);

      // Parsing respons
      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      print('Error creating additional payment: $e');
      if (e is PostgrestException) {
        throw Exception('Terjadi kesalahan database: ${e.message}');
      }
      throw Exception('Gagal membuat pembayaran: ${e.toString()}');
    }
  }
}
