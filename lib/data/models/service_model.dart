class ServiceModel {
  dynamic id;
  final String userId;
  final String fullname;
  final String whatsapp;
  final String address;
  final String device;
  final String problem;
  final String? picture;
  final String? video;
  final String? price;
  final String brand;
  final String model;
  final String description;
  final String shippingMethod;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final String? customerEmail;
  final String? status;

  ServiceModel({
    this.id,
    required this.userId,
    required this.fullname,
    required this.whatsapp,
    required this.address,
    required this.device,
    required this.problem,
    required this.brand,
    required this.model,
    required this.description,
    required this.shippingMethod,
    this.picture,
    this.video,
    this.price,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.customerEmail,
    this.status,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    double? parseCoordinate(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          print('Error parsing coordinate: $value');
          return null;
        }
      }
      return null;
    }

    return ServiceModel(
      id: json['id'],
      userId: json['user_id'] ?? '',
      fullname: json['fullname'] ?? '',
      whatsapp: json['whatsapp'] ?? '',
      address: json['address'] ?? '',
      device: json['device'] ?? '',
      problem: json['problem'] ?? '',
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      description: json['description'] ?? '',
      shippingMethod: json['shipping_method'] ?? 'pickup',
      picture: json['picture_url'],
      video: json['video_url'],
      price: json['service_cost']?.toString(),
      latitude: parseCoordinate(json['latitude']),
      longitude: parseCoordinate(json['longitude']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      customerEmail: json['customer_email'],
      status: json['status']?.toString().toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'fullname': fullname,
      'whatsapp': whatsapp,
      'address': address,
      'device': device,
      'problem': problem,
      'brand': brand,
      'model': model,
      'description': description,
      'shipping_method': shippingMethod,
      'picture_url': picture,
      'video_url': video,
      'service_cost': price,
      'latitude': latitude?.toString(),
      'longitude': longitude?.toString(),
      'created_at': createdAt?.toIso8601String(),
      'customer_email': customerEmail,
      'status': status,
    };
  }
}
