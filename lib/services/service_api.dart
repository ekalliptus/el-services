import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:servicehponline/models/service_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ServiceApi {
  final String baseUrl = dotenv.env['BASE_URL'] ?? '';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<ServiceModel> createService(ServiceModel service) async {
    try {
      // Pastikan service memiliki userId dari user yang sedang login
      final serviceData = {
        'id': service.id,
        'userId': _auth.currentUser?.uid ?? "",
        'fullname': service.fullname,
        'whatsapp': service.whatsapp,
        'address': service.address,
        'device': service.device,
        'problem': service.problem,
        'brand': service.brand,
        'description': service.description,
        'shippingMethod': service.shippingMethod,
        'picture': service.picture,
        'video': service.video,
        'price': service.price,
      };

      // Tambahkan koordinat jika metode pengiriman adalah Jemput
      if (service.shippingMethod == 'Jemput') {
        serviceData['latitude'] = service.latitude?.toString();
        serviceData['longitude'] = service.longitude?.toString();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/service'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(serviceData),
      );

      if (response.statusCode == 201) {
        return ServiceModel.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create service: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to create service: $e');
    }
  }

  Future<List<ServiceModel>> getServiceHistory() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/service?userId=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => ServiceModel.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to get service history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get service history: $e');
    }
  }
}
