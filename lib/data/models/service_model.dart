class ServiceModel {
  dynamic id;
  final String userId;
  final String fullname;
  final String phoneNumber;
  final String address;
  final String device;
  final String problem;
  final String? pictureDamage;
  final String? pictureFront;
  final String? pictureBack;
  final String? video;
  final String? price;
  final String brand;
  final String model;
  final String description;
  final String shippingMethod;
  final String note;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final String? customerEmail;
  final String? status;
  final String? devicePassword;
  final String? devicePasswordType;

  ServiceModel({
    this.id,
    required this.userId,
    required this.fullname,
    required this.phoneNumber,
    required this.address,
    required this.device,
    required this.problem,
    required this.brand,
    required this.model,
    required this.description,
    required this.shippingMethod,
    this.note = '',
    this.pictureDamage,
    this.pictureFront,
    this.pictureBack,
    this.video,
    this.price,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.customerEmail,
    this.status,
    this.devicePassword,
    this.devicePasswordType,
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
      phoneNumber: json['phoneNumber'] ?? '',
      address: json['address'] ?? '',
      device: json['device'] ?? '',
      problem: json['problem'] ?? '',
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      description: json['description'] ?? '',
      shippingMethod: json['shipping_method'] ?? 'pickup',
      note: json['note'] ?? '',
      pictureDamage: json['picture_damage_url'],
      pictureFront: json['picture_front_url'],
      pictureBack: json['picture_back_url'],
      video: json['video_url'],
      price: json['service_cost']?.toString(),
      latitude: parseCoordinate(json['latitude']),
      longitude: parseCoordinate(json['longitude']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      customerEmail: json['customer_email'],
      status: json['status']?.toString().toUpperCase(),
      devicePassword: json['device_password'],
      devicePasswordType: json['device_password_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'fullname': fullname,
      'phoneNumber': phoneNumber,
      'address': address,
      'device': device,
      'problem': problem,
      'brand': brand,
      'model': model,
      'description': description,
      'shipping_method': shippingMethod,
      'note': note,
      'picture_damage_url': pictureDamage,
      'picture_front_url': pictureFront,
      'picture_back_url': pictureBack,
      'video_url': video,
      'service_cost': price,
      'latitude': latitude?.toString(),
      'longitude': longitude?.toString(),
      'created_at': createdAt?.toIso8601String(),
      'customer_email': customerEmail,
      'status': status,
      'device_password': devicePassword,
      'device_password_type': devicePasswordType,
    };
  }

  // Getters for URLs
  String? get pictureDamageUrl => pictureDamage;
  String? get pictureFrontUrl => pictureFront;
  String? get pictureBackUrl => pictureBack;
  String? get videoUrl => video;
}
