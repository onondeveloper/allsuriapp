import 'package:cloud_firestore/cloud_firestore.dart';
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type; // 'estimate', 'order', 'system' 등
  final String? orderId;
  final String? estimateId;
  final bool isRead;
  final DateTime createdAt;
  final String userId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.orderId,
    this.estimateId,
    this.isRead = false,
    required this.createdAt,
    required this.userId,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? '',
      orderId: map['orderId'],
      estimateId: map['estimateId'],
      isRead: map['isRead'] ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      userId: map['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'orderId': orderId,
      'estimateId': estimateId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    String? orderId,
    String? estimateId,
    bool? isRead,
    DateTime? createdAt,
    String? userId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      orderId: orderId ?? this.orderId,
      estimateId: estimateId ?? this.estimateId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }
} 