class BusinessStats {
  final String businessId;
  final int totalReviews;
  final double averageRating;
  final int totalOrders;
  final int completedOrders;
  final DateTime updatedAt;

  BusinessStats({
    required this.businessId,
    required this.totalReviews,
    required this.averageRating,
    required this.totalOrders,
    required this.completedOrders,
    required this.updatedAt,
  });

  factory BusinessStats.fromMap(Map<String, dynamic> map) {
    return BusinessStats(
      businessId: map['business_id'] ?? '',
      totalReviews: map['total_reviews'] ?? 0,
      averageRating: (map['average_rating'] ?? 0.0).toDouble(),
      totalOrders: map['total_orders'] ?? 0,
      completedOrders: map['completed_orders'] ?? 0,
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'business_id': businessId,
      'total_reviews': totalReviews,
      'average_rating': averageRating,
      'total_orders': totalOrders,
      'completed_orders': completedOrders,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // 별점을 별 아이콘으로 변환
  String get ratingStars {
    final rating = averageRating.round();
    return '⭐' * rating;
  }

  // 별점을 텍스트로 변환
  String get ratingText {
    if (totalReviews == 0) return '평가 없음';
    
    final rating = averageRating;
    if (rating >= 4.5) return '매우 좋음';
    if (rating >= 4.0) return '좋음';
    if (rating >= 3.5) return '보통';
    if (rating >= 3.0) return '보통';
    if (rating >= 2.0) return '나쁨';
    return '매우 나쁨';
  }

  // 완료율 계산
  double get completionRate {
    if (totalOrders == 0) return 0.0;
    return (completedOrders / totalOrders) * 100;
  }

  // 리뷰가 있는지 확인
  bool get hasReviews => totalReviews > 0;

  // 평균 별점이 높은지 확인 (4.0 이상)
  bool get isHighRated => averageRating >= 4.0;

  BusinessStats copyWith({
    String? businessId,
    int? totalReviews,
    double? averageRating,
    int? totalOrders,
    int? completedOrders,
    DateTime? updatedAt,
  }) {
    return BusinessStats(
      businessId: businessId ?? this.businessId,
      totalReviews: totalReviews ?? this.totalReviews,
      averageRating: averageRating ?? this.averageRating,
      totalOrders: totalOrders ?? this.totalOrders,
      completedOrders: completedOrders ?? this.completedOrders,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'BusinessStats(businessId: $businessId, rating: $averageRating, reviews: $totalReviews)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BusinessStats && other.businessId == businessId;
  }

  @override
  int get hashCode => businessId.hashCode;
}
