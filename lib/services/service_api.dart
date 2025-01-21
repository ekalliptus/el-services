import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:servicehponline/models/service_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ServiceApi {
  static const String baseUrl =
      'https://678cfca6f067bf9e24e8e2e2.mockapi.io/api/v1';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<ServiceModel> createService(ServiceModel service) async {
    try {
      // Pastikan service memiliki userId dari user yang sedang login
      service = ServiceModel(
        id: service.id,
        fullname: service.fullname,
        address: service.address,
        device: service.device,
        problem: service.problem,
        picture: service.picture,
        video: service.video,
        price: service.price,
        userId: _auth.currentUser?.uid ?? "",
        whatsapp: service.whatsapp,
        brand: service.brand,
        model: service.model,
        description: service.description,
        shippingMethod: service.shippingMethod,
      );

      final response = await http.post(
        Uri.parse('$baseUrl/service'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(service.toJson()),
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
