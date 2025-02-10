import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:servicehponline/data/models/service_model.dart';
import 'package:servicehponline/core/services/supabase_config.dart';
import 'package:servicehponline/core/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

class PaymentService {
  final String _xenditKey = SupabaseConfig.xenditKey;
  late final SupabaseClient _supabase;
  final StorageService _storageService = StorageService();
  final firebase.FirebaseAuth _firebaseAuth = firebase.FirebaseAuth.instance;

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
      String? imageUrl;
      String? videoUrl;

      if (service.picture != null) {
        imageUrl = await _storageService.uploadImage(
          File(service.picture!),
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
        'whatsapp': service.whatsapp,
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
      };

      // Tambahkan URL media jika ada
      if (imageUrl != null) {
        serviceData['picture_url'] = imageUrl;
      }
      if (videoUrl != null) {
        serviceData['video_url'] = videoUrl;
      }

      final response = await _supabase
          .from('services')
          .insert(serviceData)
          .select()
          .single();

      print('Service data saved to Supabase: $response');

      // 3. Update nama file media dengan ID yang benar jika ada
      if (imageUrl != null || videoUrl != null) {
        final serviceId = response['id'];

        if (imageUrl != null) {
          final newImageUrl = await _storageService.uploadImage(
            File(service.picture!),
            serviceId,
          );
          await _storageService.deleteMedia(imageUrl);

          if (newImageUrl != null) {
            await _supabase
                .from('services')
                .update({'picture_url': newImageUrl}).eq('id', serviceId);
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
      // 1. Ambil data service
      final service = await _supabase
          .from('services')
          .select()
          .eq('id', serviceId)
          .single();

      if (service['service_cost'] == null) {
        throw Exception('Biaya service belum ditentukan oleh admin');
      }

      // 2. Buat invoice di Xendit
      final xenditUrl = 'https://api.xendit.co/v2/invoices';
      final basicAuth = 'Basic ${base64Encode(utf8.encode('$_xenditKey:'))}';

      final xenditPayload = {
        'external_id':
            'SERVICE-$serviceId-${DateTime.now().millisecondsSinceEpoch}',
        'amount': service['service_cost'],
        'payer_email': service['whatsapp'] + '@servicehponline.com',
        'description':
            'Pembayaran Service HP Online - ${service['device']} ${service['brand']}',
        'success_redirect_url': 'servicehponline://payment/success',
        'failure_redirect_url': 'servicehponline://payment/failed',
        'currency': 'IDR',
      };

      final xenditResponse = await http.post(
        Uri.parse(xenditUrl),
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(xenditPayload),
      );

      if (xenditResponse.statusCode != 200) {
        throw Exception('Gagal membuat invoice Xendit: ${xenditResponse.body}');
      }

      final xenditData = jsonDecode(xenditResponse.body);

      // 3. Update data service dengan invoice ID
      await _supabase.from('services').update({
        'xendit_invoice_id': xenditData['id'],
        'payment_url': xenditData['invoice_url'],
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', serviceId);

      return {
        'id': serviceId,
        'paymentUrl': xenditData['invoice_url'],
      };
    } catch (e) {
      print('Error creating payment: $e');
      throw Exception('Gagal membuat pembayaran: $e');
    }
  }

  Future<String> getPaymentStatus(String serviceId) async {
    try {
      final service = await _supabase
          .from('services')
          .select()
          .eq('id', serviceId)
          .single();

      if (service['xendit_invoice_id'] == null) {
        return service['status'] ?? 'PENDING';
      }

      final xenditUrl =
          'https://api.xendit.co/v2/invoices/${service['xendit_invoice_id']}';
      final basicAuth = 'Basic ${base64Encode(utf8.encode('$_xenditKey:'))}';

      final response = await http.get(
        Uri.parse(xenditUrl),
        headers: {
          'Authorization': basicAuth,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Gagal mengecek status pembayaran');
      }

      final data = jsonDecode(response.body);
      final status = data['status'];

      // Update status di Supabase
      await _supabase.from('services').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', serviceId);

      return status;
    } catch (e) {
      print('Error checking payment status: $e');
      return 'PENDING';
    }
  }
}
