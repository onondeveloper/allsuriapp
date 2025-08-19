// import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class Order {
  final String? id;
  final String? customerId;
  final String title;
  final String description;
  final String address;
  final DateTime visitDate;
  final String status;
  final DateTime createdAt;
  final List<String> images;
  final double estimatedPrice;
  final String? technicianId;
  final String? selectedEstimateId;
  final String category;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final bool isAnonymous;
  final bool isAwarded;
  final DateTime? awardedAt;
  final String? awardedEstimateId;
  final String? sessionId;

  // 카테고리 목록
  static const List<String> CATEGORIES = [
    '누수',
    '화장실',
    '배관',
    '난방',
    '주방',
    '리모델링',
    '기타',
  ];

  static const String STATUS_PENDING = 'pending';
  static const String STATUS_IN_PROGRESS = 'in_progress';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_CANCELLED = 'cancelled';

  Order({
    this.id,
    this.customerId,
    required this.title,
    required this.description,
    required this.address,
    required this.visitDate,
    required this.status,
    required this.createdAt,
    this.images = const [],
    this.estimatedPrice = 0.0,
    this.technicianId,
    this.selectedEstimateId,
    this.category = '기타',
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    this.isAnonymous = false,
    this.isAwarded = false,
    this.awardedAt,
    this.awardedEstimateId,
    this.sessionId,
  });

  // equipmentType getter (하위 호환성)
  String get equipmentType => category;

  // 날짜 포맷팅 getter
  String get formattedDate {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'],
      customerId: map['customerId'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      address: map['address'] ?? '',
      visitDate: map['visitDate'] != null 
          ? (map['visitDate'] is DateTime 
              ? map['visitDate'] 
              : DateTime.parse(map['visitDate'].toString()))
          : DateTime.now(),
      status: map['status'] ?? STATUS_PENDING,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] is DateTime 
              ? map['createdAt'] 
              : DateTime.parse(map['createdAt'].toString()))
          : DateTime.now(),
      images: List<String>.from(map['images'] ?? []),
      estimatedPrice: (map['estimatedPrice'] ?? 0.0).toDouble(),
      technicianId: map['technicianId'],
      selectedEstimateId: map['selectedEstimateId'],
      category: map['category'] ?? '기타',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      customerEmail: map['customerEmail'],
      isAnonymous: map['isAnonymous'] ?? false,
      isAwarded: map['isAwarded'] ?? false,
      awardedAt: map['awardedAt'] != null 
          ? (map['awardedAt'] is DateTime 
              ? map['awardedAt'] 
              : DateTime.parse(map['awardedAt'].toString()))
          : null,
      awardedEstimateId: map['awardedEstimateId'],
      sessionId: map['sessionId'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      if (id != null && id!.isNotEmpty) 'id': id,
      'customerId': customerId,
      'title': title,
      'description': description,
      'address': address,
      'visitDate': visitDate.toIso8601String(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'images': images,
      'estimatedPrice': estimatedPrice,
      'technicianId': technicianId,
      'selectedEstimateId': selectedEstimateId,
      'category': category,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'isAnonymous': isAnonymous,
      'isAwarded': isAwarded,
      'awardedAt': awardedAt?.toIso8601String(),
      'awardedEstimateId': awardedEstimateId,
      if (sessionId != null) 'sessionId': sessionId,
    };
    return map;
  }

  Order copyWith({
    String? id,
    String? customerId,
    String? title,
    String? description,
    String? address,
    DateTime? visitDate,
    String? status,
    DateTime? createdAt,
    List<String>? images,
    double? estimatedPrice,
    String? technicianId,
    String? selectedEstimateId,
    String? category,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    bool? isAnonymous,
    bool? isAwarded,
    DateTime? awardedAt,
    String? awardedEstimateId,
    String? sessionId,
  }) {
    return Order(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      title: title ?? this.title,
      description: description ?? this.description,
      address: address ?? this.address,
      visitDate: visitDate ?? this.visitDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      images: images ?? this.images,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      technicianId: technicianId ?? this.technicianId,
      selectedEstimateId: selectedEstimateId ?? this.selectedEstimateId,
      category: category ?? this.category,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isAwarded: isAwarded ?? this.isAwarded,
      awardedAt: awardedAt ?? this.awardedAt,
      awardedEstimateId: awardedEstimateId ?? this.awardedEstimateId,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}
