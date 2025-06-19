import 'role.dart';

class User {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? businessName;  // For business users
  final String? businessLicense;  // For business users
  final String? phoneNumber;
  final String? address;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.businessName,
    this.businessLicense,
    this.phoneNumber,
    this.address,
    DateTime? createdAt,
    this.lastLoginAt,
    this.isActive = true,
  }) : this.createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.value,
      'businessName': businessName,
      'businessLicense': businessLicense,
      'phoneNumber': phoneNumber,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      email: map['email'],
      name: map['name'],
      role: UserRole.fromString(map['role']),
      businessName: map['businessName'],
      businessLicense: map['businessLicense'],
      phoneNumber: map['phoneNumber'],
      address: map['address'],
      createdAt: DateTime.parse(map['createdAt']),
      lastLoginAt: map['lastLoginAt'] != null ? DateTime.parse(map['lastLoginAt']) : null,
      isActive: map['isActive'] ?? true,
    );
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    String? businessName,
    String? businessLicense,
    String? phoneNumber,
    String? address,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      businessName: businessName ?? this.businessName,
      businessLicense: businessLicense ?? this.businessLicense,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
    );
  }
} 