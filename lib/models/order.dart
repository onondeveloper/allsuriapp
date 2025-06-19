// import 'package:intl/intl.dart';
// import 'package:uuid/uuid.dart';

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

  final String id;
  final String customerId;
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

  Order({
    required this.id,
    required this.customerId,
    required this.title,
    required this.description,
    required this.address,
    required this.visitDate,
    required this.status,
    required this.createdAt,
    required this.images,
    this.estimatedPrice = 0.0,
    this.technicianId,
    this.selectedEstimateId,
  }) {
    if (!VALID_STATUSES.contains(status)) {
      throw ArgumentError('Invalid status: $status');
    }
  }

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
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'],
      customerId: map['customerId'],
      title: map['title'],
      description: map['description'],
      address: map['address'],
      visitDate: DateTime.parse(map['visitDate']),
      status: map['status'],
      createdAt: DateTime.parse(map['createdAt']),
      images: List<String>.from(map['images']),
      estimatedPrice: map['estimatedPrice']?.toDouble() ?? 0.0,
      technicianId: map['technicianId'],
      selectedEstimateId: map['selectedEstimateId'],
    );
  }

  String get formattedDate {
    return '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}';
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
  };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    customerId: json['customerId'] as String,
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
  );
}