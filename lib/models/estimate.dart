import 'package:flutter/foundation.dart';

class Estimate {
  final String id;
  final String orderId;
  final String customerId;
  final String customerName;
  final String businessId;
  final String businessName;
  final String businessPhone;
  final String equipmentType;
  final double amount;
  final String description;
  final int estimatedDays;
  final DateTime createdAt;
  final DateTime visitDate;
  final String status;
  final String? transferredBy;
  final DateTime? transferredAt;
  final String? transferReason;
  final DateTime? awardedAt;

  static const String STATUS_PENDING = 'pending';
  static const String STATUS_APPROVED = 'approved';
  static const String STATUS_REJECTED = 'rejected';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_TRANSFERRED = 'transferred';
  static const String STATUS_ACCEPTED = 'accepted';
  static const String STATUS_AWARDED = 'awarded';

  // 하위 호환성을 위한 getter들
  double get price => amount;
  String get technicianId => businessId;
  String get technicianName => businessName;

  Estimate({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.businessId,
    required this.businessName,
    required this.businessPhone,
    required this.equipmentType,
    required this.amount,
    required this.description,
    required this.estimatedDays,
    required this.createdAt,
    required this.visitDate,
    required this.status,
    this.transferredBy,
    this.transferredAt,
    this.transferReason,
    this.awardedAt,
  });

  // 빈 견적 생성자
  factory Estimate.empty() {
    return Estimate(
      id: '',
      orderId: '',
      customerId: '',
      customerName: '',
      businessId: '',
      businessName: '',
      businessPhone: '',
      equipmentType: '',
      amount: 0.0,
      description: '',
      estimatedDays: 0,
      createdAt: DateTime.now(),
      visitDate: DateTime.now(),
      status: STATUS_PENDING,
    );
  }

  Estimate copyWith({
    String? id,
    String? orderId,
    String? customerId,
    String? customerName,
    String? businessId,
    String? businessName,
    String? businessPhone,
    String? equipmentType,
    double? amount,
    String? description,
    int? estimatedDays,
    DateTime? createdAt,
    DateTime? visitDate,
    String? status,
    String? transferredBy,
    DateTime? transferredAt,
    String? transferReason,
    DateTime? awardedAt,
  }) {
    return Estimate(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      businessPhone: businessPhone ?? this.businessPhone,
      equipmentType: equipmentType ?? this.equipmentType,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      estimatedDays: estimatedDays ?? this.estimatedDays,
      createdAt: createdAt ?? this.createdAt,
      visitDate: visitDate ?? this.visitDate,
      status: status ?? this.status,
      transferredBy: transferredBy ?? this.transferredBy,
      transferredAt: transferredAt ?? this.transferredAt,
      transferReason: transferReason ?? this.transferReason,
      awardedAt: awardedAt ?? this.awardedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'customerId': customerId,
      'customerName': customerName,
      'businessId': businessId,
      'businessName': businessName,
      'businessPhone': businessPhone,
      'equipmentType': equipmentType,
      'amount': amount,
      'description': description,
      'estimatedDays': estimatedDays,
      'createdAt': createdAt.toIso8601String(),
      'visitDate': visitDate.toIso8601String(),
      'status': status,
      'transferredBy': transferredBy,
      'transferredAt': transferredAt?.toIso8601String(),
      'transferReason': transferReason,
      'awardedAt': awardedAt?.toIso8601String(),
    };
  }

  factory Estimate.fromMap(Map<String, dynamic> map) {
    return Estimate(
      id: map['id'] ?? '',
      orderId: map['orderId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      businessId: map['businessId'] ?? '',
      businessName: map['businessName'] ?? '',
      businessPhone: map['businessPhone'] ?? '',
      equipmentType: map['equipmentType'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      estimatedDays: map['estimatedDays'] ?? 0,
      createdAt: DateTime.parse(map['createdAt']),
      visitDate: DateTime.parse(map['visitDate']),
      status: map['status'] ?? STATUS_PENDING,
      transferredBy: map['transferredBy'],
      transferredAt: map['transferredAt'] != null ? DateTime.parse(map['transferredAt']) : null,
      transferReason: map['transferReason'],
      awardedAt: map['awardedAt'] != null ? DateTime.parse(map['awardedAt']) : null,
    );
  }
}
