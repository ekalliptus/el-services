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
    required this.model,
    required this.description,
    required this.shippingMethod,
    this.picture,
    this.video,
    this.price,
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
      model: json['model'] ?? '',
      description: json['description'] ?? '',
      shippingMethod: json['shippingMethod'] ?? 'pickup',
      picture: json['picture'],
      video: json['video'],
      price: json['price']?.toString() ?? '-',
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
      'model': model,
      'description': description,
      'shippingMethod': shippingMethod,
      'picture': picture,
      'video': video,
      'price': price,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
