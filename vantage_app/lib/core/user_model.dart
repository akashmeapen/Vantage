class User {
  final String id;
  final String displayName;
  final String publicKey;

  User({
    required this.id,
    required this.displayName,
    required this.publicKey,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      publicKey: json['public_key'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'public_key': publicKey,
    };
  }
}
