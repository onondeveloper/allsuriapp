// Firestore import 제거: Supabase 모델 전용

class Job {
  final String? id;
  final String title;
  final String description;
  final String ownerBusinessId;
  final String? assignedBusinessId;
  final String? transferToBusinessId;
  final double? budgetAmount;
  final double? awardedAmount;
  final double? commissionRate;
  final double? commissionAmount;
  final String status; // created, pending_transfer, assigned, completed, cancelled
  final String? location;
  final String? category;
  final String urgency;
  final List<String>? mediaUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Job({
    this.id,
    required this.title,
    required this.description,
    required this.ownerBusinessId,
    this.assignedBusinessId,
    this.transferToBusinessId,
    this.budgetAmount,
    this.awardedAmount,
    this.commissionRate,
    this.commissionAmount,
    required this.status,
    this.location,
    this.category,
    this.urgency = 'normal',
    this.mediaUrls,
    required this.createdAt,
    this.updatedAt,
  });

  factory Job.fromMap(Map<String, dynamic> data, String id) {
    return Job(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      ownerBusinessId: data['owner_business_id'] ?? '',
      assignedBusinessId: data['assigned_business_id'],
      transferToBusinessId: data['transfer_to_business_id'],
      budgetAmount: (data['budget_amount'] != null) ? (data['budget_amount'] as num).toDouble() : null,
      awardedAmount: (data['awarded_amount'] != null) ? (data['awarded_amount'] as num).toDouble() : null,
      commissionRate: (data['commission_rate'] != null) ? (data['commission_rate'] as num).toDouble() : null,
      commissionAmount: (data['commission_amount'] != null) ? (data['commission_amount'] as num).toDouble() : null,
      status: data['status'] ?? 'created',
      location: data['location'],
      category: data['category'],
      urgency: data['urgency'] ?? 'normal',
      mediaUrls: data['media_urls'] != null ? List<String>.from(data['media_urls'] ?? []) : null,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: data['updated_at'] != null ? DateTime.tryParse(data['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'owner_business_id': ownerBusinessId,
      'assigned_business_id': assignedBusinessId,
      'transfer_to_business_id': transferToBusinessId,
      'budget_amount': budgetAmount,
      'awarded_amount': awardedAmount,
      'commission_rate': commissionRate,
      'commission_amount': commissionAmount,
      'status': status,
      'location': location,
      'category': category,
      'urgency': urgency,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
    // Only send media_urls when present to allow DB default '{}' to apply otherwise
    if (mediaUrls != null) {
      map['media_urls'] = mediaUrls;
    }
    return map;
  }

  Job copyWith({
    String? id,
    String? title,
    String? description,
    String? ownerBusinessId,
    String? assignedBusinessId,
    String? transferToBusinessId,
    double? budgetAmount,
    double? awardedAmount,
    double? commissionRate,
    double? commissionAmount,
    String? status,
    String? location,
    String? category,
    String? urgency,
    List<String>? mediaUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Job(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      ownerBusinessId: ownerBusinessId ?? this.ownerBusinessId,
      assignedBusinessId: assignedBusinessId ?? this.assignedBusinessId,
      transferToBusinessId: transferToBusinessId ?? this.transferToBusinessId,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      awardedAmount: awardedAmount ?? this.awardedAmount,
      commissionRate: commissionRate ?? this.commissionRate,
      status: status ?? this.status,
      location: location ?? this.location,
      category: category ?? this.category,
      urgency: urgency ?? this.urgency,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


