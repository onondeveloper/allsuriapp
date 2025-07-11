class AnonymousUser {
  final String id;
  final String? name;
  final String? phone;
  final String? email;
  final DateTime createdAt;
  final String? deviceId;
  final String? sessionToken;

  AnonymousUser({
    required this.id,
    this.name,
    this.phone,
    this.email,
    required this.createdAt,
    this.deviceId,
    this.sessionToken,
  });

  factory AnonymousUser.fromMap(Map<String, dynamic> map) {
    return AnonymousUser(
      id: map['id'] ?? '',
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      deviceId: map['deviceId'],
      sessionToken: map['sessionToken'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'deviceId': deviceId,
      'sessionToken': sessionToken,
    };
  }

  AnonymousUser copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    DateTime? createdAt,
    String? deviceId,
    String? sessionToken,
  }) {
    return AnonymousUser(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      deviceId: deviceId ?? this.deviceId,
      sessionToken: sessionToken ?? this.sessionToken,
    );
  }
} 