class UserModel {
  final String id;
  final String username;

  UserModel({
    required this.id,
    required this.username,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
    );
  }
}
