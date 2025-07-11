class ChatRoom {
  final String id;
  final String estimateId;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String businessId;
  final String businessName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessage;
  final int unreadCount;
  final bool isAnonymous;

  ChatRoom({
    required this.id,
    required this.estimateId,
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.businessId,
    required this.businessName,
    required this.isActive,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.isAnonymous = false,
  });

  factory ChatRoom.fromMap(Map<String, dynamic> map) {
    return ChatRoom(
      id: map['id'] ?? '',
      estimateId: map['estimateId'] ?? '',
      customerId: map['customerId'],
      customerName: map['customerName'],
      customerPhone: map['customerPhone'],
      businessId: map['businessId'] ?? '',
      businessName: map['businessName'] ?? '',
      isActive: map['isActive'] ?? false,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      lastMessageAt: map['lastMessageAt'] != null 
          ? DateTime.parse(map['lastMessageAt']) 
          : null,
      lastMessage: map['lastMessage'],
      unreadCount: map['unreadCount'] ?? 0,
      isAnonymous: map['isAnonymous'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'estimateId': estimateId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'businessId': businessId,
      'businessName': businessName,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'isAnonymous': isAnonymous,
    };
  }

  ChatRoom copyWith({
    String? id,
    String? estimateId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? businessId,
    String? businessName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    String? lastMessage,
    int? unreadCount,
    bool? isAnonymous,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      estimateId: estimateId ?? this.estimateId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }
} 