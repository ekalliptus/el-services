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
  final String description;
  final String shippingMethod;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;

  ServiceModel({
    this.id,
    required this.userId,
    required this.fullname,
    required this.whatsapp,
    required this.address,
    required this.device,
    required this.problem,
    required this.brand,
    required this.description,
    required this.shippingMethod,
    this.picture,
    this.video,
    this.price,
    this.latitude,
    this.longitude,
    this.createdAt,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'],
      userId: json['userId'] ?? '',
      fullname: json['fullname'] ?? '',
      whatsapp: json['whatsapp'] ?? '',
      address: json['address'] ?? '',
      device: json['device'] ?? '',
      problem: json['problem'] ?? '',
      brand: json['brand'] ?? '',
      description: json['description'] ?? '',
      shippingMethod: json['shippingMethod'] ?? 'pickup',
      picture: json['picture'],
      video: json['video'],
      price: json['price']?.toString() ?? '-',
      latitude: json['latitude'] != null
          ? double.parse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.parse(json['longitude'].toString())
          : null,
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fullname': fullname,
      'whatsapp': whatsapp,
      'address': address,
      'device': device,
      'problem': problem,
      'brand': brand,
      'description': description,
      'shippingMethod': shippingMethod,
      'picture': picture,
      'video': video,
      'price': price,
      'latitude': latitude?.toString(),
      'longitude': longitude?.toString(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
