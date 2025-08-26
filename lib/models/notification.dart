class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type; // 'estimate', 'order', 'system' 등
  final String? orderId;
  final String? estimateId;
  final String? jobId;
  final String? jobTitle;
  final String? region;
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
    this.jobId,
    this.jobTitle,
    this.region,
    this.isRead = false,
    required this.createdAt,
    required this.userId,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    String _str(dynamic v) => v?.toString() ?? '';
    DateTime _dt(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }
    return NotificationModel(
      id: _str(map['id']),
      title: _str(map['title']),
      message: _str(map['message'] ?? map['body']),
      type: _str(map['type']),
      orderId: map['orderId']?.toString() ?? map['orderid']?.toString(),
      estimateId: map['estimateId']?.toString() ?? map['estimateid']?.toString(),
      jobId: map['jobId']?.toString() ?? map['jobid']?.toString(),
      jobTitle: map['jobTitle']?.toString() ?? map['jobtitle']?.toString(),
      region: map['region']?.toString(),
      isRead: (map['isRead'] as bool?) ?? (map['isread'] as bool?) ?? false,
      createdAt: _dt(map['createdAt'] ?? map['createdat']),
      userId: _str(map['userId'] ?? map['userid']),
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
      'jobId': jobId,
      'jobTitle': jobTitle,
      'region': region,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
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