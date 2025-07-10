class Estimate {
  static const String STATUS_PENDING = 'PENDING';
  static const String STATUS_ACCEPTED = 'ACCEPTED';
  static const String STATUS_REJECTED = 'REJECTED';
  static const String STATUS_CANCELLED = 'CANCELLED';
  static const String STATUS_AWARDED = 'AWARDED'; // 낙찰됨

  // 한국어 상태명
  static const Map<String, String> STATUS_LABELS = {
    STATUS_PENDING: '대기',
    STATUS_ACCEPTED: '수락',
    STATUS_REJECTED: '거절',
    STATUS_CANCELLED: '취소',
    STATUS_AWARDED: '낙찰',
  };

  final String id;
  final String? orderId; // 이관 견적의 경우 null일 수 있음
  final String technicianId; // 사업자 ID
  final String technicianName; // 사업자명
  final double price;
  final String description;
  final int estimatedDays; // 예상 작업 기간
  final String status; // 견적 상태 (PENDING, ACCEPTED, REJECTED, CANCELLED, AWARDED)
  final DateTime createdAt;
  final DateTime visitDate; // 방문 희망일
  
  // 고객 정보 (이관 견적용)
  final String? customerName;
  final String? customerPhone;
  final String? address;
  
  // 이관 견적 여부
  final bool isTransferEstimate;
  
  // 낙찰 관련 정보
  final bool isAwarded; // 낙찰 여부
  final DateTime? awardedAt; // 낙찰 시간
  final String? awardedBy; // 낙찰한 사용자 ID (고객)

  Estimate({
    required this.id,
    this.orderId,
    required this.technicianId,
    required this.technicianName,
    required this.price,
    required this.description,
    this.estimatedDays = 1,
    required this.status,
    required this.createdAt,
    required this.visitDate,
    this.customerName,
    this.customerPhone,
    this.address,
    this.isTransferEstimate = false,
    this.isAwarded = false,
    this.awardedAt,
    this.awardedBy,
  });

  Estimate.empty()
      : id = '',
        orderId = null,
        technicianId = '',
        technicianName = '',
        price = 0,
        description = '',
        estimatedDays = 1,
        status = STATUS_PENDING,
        createdAt = DateTime.now(),
        visitDate = DateTime.now().add(const Duration(days: 1)),
        customerName = null,
        customerPhone = null,
        address = null,
        isTransferEstimate = false,
        isAwarded = false,
        awardedAt = null,
        awardedBy = null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderId': orderId,
        'technicianId': technicianId,
        'technicianName': technicianName,
        'price': price,
        'description': description,
        'estimatedDays': estimatedDays,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'visitDate': visitDate.toIso8601String(),
        'customerName': customerName,
        'customerPhone': customerPhone,
        'address': address,
        'isTransferEstimate': isTransferEstimate,
        'isAwarded': isAwarded,
        'awardedAt': awardedAt?.toIso8601String(),
        'awardedBy': awardedBy,
      };

  factory Estimate.fromMap(Map<String, dynamic> map) {
    return Estimate(
        id: map['id'],
        orderId: map['orderId'],
        technicianId: map['technicianId'],
        technicianName: map['technicianName'] ?? '사업자',
        price: (map['price'] as num).toDouble(),
        description: map['description'],
        estimatedDays: map['estimatedDays'] ?? 1,
        status: map['status'] ?? STATUS_PENDING,
        createdAt: DateTime.parse(map['createdAt']),
        visitDate: map['visitDate'] != null ? DateTime.parse(map['visitDate']) : DateTime.now().add(const Duration(days: 1)),
        customerName: map['customerName'],
        customerPhone: map['customerPhone'],
        address: map['address'],
        isTransferEstimate: map['isTransferEstimate'] ?? false,
        isAwarded: map['isAwarded'] ?? false,
        awardedAt: map['awardedAt'] != null ? DateTime.parse(map['awardedAt']) : null,
        awardedBy: map['awardedBy'],
      );
  }

  // JSON 직렬화
  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'technicianId': technicianId,
        'technicianName': technicianName,
        'price': price,
        'description': description,
        'estimatedDays': estimatedDays,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'visitDate': visitDate.toIso8601String(),
        'customerName': customerName,
        'customerPhone': customerPhone,
        'address': address,
        'isTransferEstimate': isTransferEstimate,
        'isAwarded': isAwarded,
        'awardedAt': awardedAt?.toIso8601String(),
        'awardedBy': awardedBy,
      };

  // JSON 역직렬화
  factory Estimate.fromJson(Map<String, dynamic> json) => Estimate(
        id: json['id'] as String,
        orderId: json['orderId'] as String?,
        technicianId: json['technicianId'] as String,
        technicianName: json['technicianName'] as String? ?? '사업자',
        price: (json['price'] as num).toDouble(),
        description: json['description'] as String,
        estimatedDays: json['estimatedDays'] as int? ?? 1,
        status: json['status'] as String? ?? STATUS_PENDING,
        createdAt: DateTime.parse(json['createdAt'] as String),
        visitDate: json['visitDate'] != null ? DateTime.parse(json['visitDate'] as String) : DateTime.now().add(const Duration(days: 1)),
        customerName: json['customerName'] as String?,
        customerPhone: json['customerPhone'] as String?,
        address: json['address'] as String?,
        isTransferEstimate: json['isTransferEstimate'] as bool? ?? false,
        isAwarded: json['isAwarded'] as bool? ?? false,
        awardedAt: json['awardedAt'] != null ? DateTime.parse(json['awardedAt'] as String) : null,
        awardedBy: json['awardedBy'] as String?,
      );

  // 복사본 생성 with 메서드
  Estimate copyWith({
    String? id,
    String? orderId,
    String? technicianId,
    String? technicianName,
    double? price,
    String? description,
    int? estimatedDays,
    String? status,
    DateTime? createdAt,
    DateTime? visitDate,
    String? customerName,
    String? customerPhone,
    String? address,
    bool? isTransferEstimate,
    bool? isAwarded,
    DateTime? awardedAt,
    String? awardedBy,
  }) {
    return Estimate(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      price: price ?? this.price,
      description: description ?? this.description,
      estimatedDays: estimatedDays ?? this.estimatedDays,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      visitDate: visitDate ?? this.visitDate,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      address: address ?? this.address,
      isTransferEstimate: isTransferEstimate ?? this.isTransferEstimate,
      isAwarded: isAwarded ?? this.isAwarded,
      awardedAt: awardedAt ?? this.awardedAt,
      awardedBy: awardedBy ?? this.awardedBy,
    );
  }

  // 견적이 낙찰되었는지 확인
  bool get isAwardedEstimate => status == STATUS_AWARDED || isAwarded;

  // 한국어 상태명 반환
  String get statusLabel => STATUS_LABELS[status] ?? status;
  
  // 방문 희망일 포맷팅
  String get formattedVisitDate {
    return '${visitDate.year}-${visitDate.month.toString().padLeft(2, '0')}-${visitDate.day.toString().padLeft(2, '0')}';
  }
  
  // 가격 포맷팅
  String get formattedPrice {
    return '${price.toStringAsFixed(0)}원';
  }
}
