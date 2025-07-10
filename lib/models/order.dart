// import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

enum OrderStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

class Order {
  static const String STATUS_PENDING = 'pending';
  static const String STATUS_ESTIMATING = 'estimating';
  static const String STATUS_IN_PROGRESS = 'in_progress';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_CANCELLED = 'cancelled';

  static const List<String> VALID_STATUSES = [
    STATUS_PENDING,
    STATUS_ESTIMATING,
    STATUS_IN_PROGRESS,
    STATUS_COMPLETED,
    STATUS_CANCELLED,
  ];

  // 설비 관련 카테고리
  static const List<String> CATEGORIES = [
    '에어컨',
    '냉장고',
    '세탁기',
    'TV/오디오',
    '컴퓨터/노트북',
    '전자레인지',
    '가스레인지',
    '청소기',
    '공기청정기',
    '온수기',
    '보일러',
    '전기/조명',
    '수도/배관',
    '문/창문',
    '가구',
    '기타',
  ];

  final String id;
  final String? customerId; // 익명 사용자는 null일 수 있음
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
  final String? category;
  
  // 익명 사용자를 위한 연락처 정보
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final bool isAnonymous;
  
  // 낙찰 관련 정보
  final bool isAwarded; // 낙찰 여부
  final DateTime? awardedAt; // 낙찰 시간
  final String? awardedEstimateId; // 낙찰된 견적 ID

  Order({
    String? id,
    this.customerId,
    required this.title,
    required this.description,
    required this.address,
    required this.visitDate,
    required this.status,
    DateTime? createdAt,
    this.images = const [],
    this.estimatedPrice = 0.0,
    this.technicianId,
    this.selectedEstimateId,
    this.category,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.isAnonymous = false,
    this.isAwarded = false,
    this.awardedAt,
    this.awardedEstimateId,
  }) : 
    id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'],
      customerId: map['customerId'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      address: map['address'] ?? '',
      visitDate: DateTime.parse(map['visitDate']),
      status: map['status'] ?? STATUS_PENDING,
      createdAt: DateTime.parse(map['createdAt']),
      images: List<String>.from(map['images'] ?? []),
      estimatedPrice: map['estimatedPrice']?.toDouble() ?? 0.0,
      technicianId: map['technicianId'],
      selectedEstimateId: map['selectedEstimateId'],
      category: map['category'],
      customerName: map['customerName'],
      customerPhone: map['customerPhone'],
      customerEmail: map['customerEmail'],
      isAnonymous: map['isAnonymous'] ?? false,
      isAwarded: map['isAwarded'] ?? false,
      awardedAt: map['awardedAt'] != null ? DateTime.parse(map['awardedAt']) : null,
      awardedEstimateId: map['awardedEstimateId'],
    );
  }

  String get formattedDate {
    return '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}';
  }

  // 익명 사용자의 연락처 정보 노출 여부 확인
  bool get shouldShowContactInfo => !isAnonymous || isAwarded;

  // 익명 사용자의 전화번호 (낙찰 전에는 마스킹)
  String get maskedPhoneNumber {
    if (!isAnonymous || isAwarded) {
      return customerPhone ?? '';
    }
    // 전화번호 마스킹 (예: 010-1234-5678 -> 010-****-5678)
    if (customerPhone?.length == 11) {
      return '${customerPhone?.substring(0, 3)}-****-${customerPhone?.substring(7)}';
    }
    return '***-****-****';
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
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    bool? isAnonymous,
    bool? isAwarded,
    DateTime? awardedAt,
    String? awardedEstimateId,
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
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isAwarded: isAwarded ?? this.isAwarded,
      awardedAt: awardedAt ?? this.awardedAt,
      awardedEstimateId: awardedEstimateId ?? this.awardedEstimateId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
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
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
        'isAnonymous': isAnonymous,
        'isAwarded': isAwarded,
        'awardedAt': awardedAt?.toIso8601String(),
        'awardedEstimateId': awardedEstimateId,
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        customerId: json['customerId'] as String?,
        title: json['title'] as String,
        description: json['description'] as String,
        address: json['address'] as String,
        visitDate: DateTime.parse(json['visitDate'] as String),
        status: json['status'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        images: List<String>.from(json['images'] as List),
        estimatedPrice: (json['estimatedPrice'] as num).toDouble(),
        technicianId: json['technicianId'] as String?,
        selectedEstimateId: json['selectedEstimateId'] as String?,
        customerName: json['customerName'] as String?,
        customerPhone: json['customerPhone'] as String?,
        customerEmail: json['customerEmail'] as String?,
        isAnonymous: json['isAnonymous'] as bool? ?? false,
        isAwarded: json['isAwarded'] as bool? ?? false,
        awardedAt: json['awardedAt'] != null ? DateTime.parse(json['awardedAt'] as String) : null,
        awardedEstimateId: json['awardedEstimateId'] as String?,
      );

  @override
  String toString() {
    return 'Order(id: $id, title: $title, status: $status)';
  }
}
