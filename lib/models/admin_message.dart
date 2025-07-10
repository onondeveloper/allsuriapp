class AdminMessage {
  final String id;
  final String title;
  final String content;
  final String recipientType; // 'all', 'business', 'customer', 'specific'
  final List<String> recipients; // 특정 사용자 ID들
  final String senderId;
  final String senderName;
  final DateTime createdAt;
  final DateTime? sentAt;
  final String status; // 'draft', 'sent', 'failed'
  final int? readCount;
  final int? totalRecipients;

  AdminMessage({
    required this.id,
    required this.title,
    required this.content,
    required this.recipientType,
    required this.recipients,
    required this.senderId,
    required this.senderName,
    required this.createdAt,
    this.sentAt,
    required this.status,
    this.readCount,
    this.totalRecipients,
  });

  factory AdminMessage.fromJson(Map<String, dynamic> json) {
    return AdminMessage(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      recipientType: json['recipientType'] ?? '',
      recipients: List<String>.from(json['recipients'] ?? []),
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      sentAt: json['sentAt'] != null ? DateTime.parse(json['sentAt']) : null,
      status: json['status'] ?? 'draft',
      readCount: json['readCount'],
      totalRecipients: json['totalRecipients'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'recipientType': recipientType,
      'recipients': recipients,
      'senderId': senderId,
      'senderName': senderName,
      'createdAt': createdAt.toIso8601String(),
      'sentAt': sentAt?.toIso8601String(),
      'status': status,
      'readCount': readCount,
      'totalRecipients': totalRecipients,
    };
  }

  AdminMessage copyWith({
    String? id,
    String? title,
    String? content,
    String? recipientType,
    List<String>? recipients,
    String? senderId,
    String? senderName,
    DateTime? createdAt,
    DateTime? sentAt,
    String? status,
    int? readCount,
    int? totalRecipients,
  }) {
    return AdminMessage(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      recipientType: recipientType ?? this.recipientType,
      recipients: recipients ?? this.recipients,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      status: status ?? this.status,
      readCount: readCount ?? this.readCount,
      totalRecipients: totalRecipients ?? this.totalRecipients,
    );
  }
} 