class Estimate {
  final String id;
  final String orderId;
  final String technicianId; // 사업자 ID
  final double price;
  final String description;
  final int estimatedDays; // 예상 작업 기간
  final String status; // 견적 상태 (PENDING, SELECTED, REJECTED)
  final DateTime createdAt;

  Estimate({
    required this.id,
    required this.orderId,
    required this.technicianId,
    required this.price,
    required this.description,
    required this.estimatedDays,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'orderId': orderId,
    'technicianId': technicianId,
    'price': price,
    'description': description,
    'estimatedDays': estimatedDays,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Estimate.fromMap(Map<String, dynamic> map) => Estimate(
    id: map['id'],
    orderId: map['orderId'],
    technicianId: map['technicianId'],
    price: (map['price'] as num).toDouble(),
    description: map['description'],
    estimatedDays: map['estimatedDays'] ?? 1,
    status: map['status'] ?? 'PENDING',
    createdAt: DateTime.parse(map['createdAt']),
  );

  // JSON 직렬화
  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'technicianId': technicianId,
    'price': price,
    'description': description,
    'estimatedDays': estimatedDays,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };

  // JSON 역직렬화
  factory Estimate.fromJson(Map<String, dynamic> json) => Estimate(
    id: json['id'] as String,
    orderId: json['orderId'] as String,
    technicianId: json['technicianId'] as String,
    price: (json['price'] as num).toDouble(),
    description: json['description'] as String,
    estimatedDays: json['estimatedDays'] as int? ?? 1,
    status: json['status'] as String? ?? 'PENDING',
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  // 복사본 생성 with 메서드
  Estimate copyWith({
    String? id,
    String? orderId,
    String? technicianId,
    double? price,
    String? description,
    int? estimatedDays,
    String? status,
    DateTime? createdAt,
  }) {
    return Estimate(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      technicianId: technicianId ?? this.technicianId,
      price: price ?? this.price,
      description: description ?? this.description,
      estimatedDays: estimatedDays ?? this.estimatedDays,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}