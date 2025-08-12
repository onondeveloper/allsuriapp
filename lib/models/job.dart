import 'package:cloud_firestore/cloud_firestore.dart';

class Job {
  final String id;
  final String title;
  final String description;
  final String ownerBusinessId;
  final String? assignedBusinessId;
  final String? transferToBusinessId;
  final double? budgetAmount;
  final double? awardedAmount;
  final String status; // created, pending_transfer, assigned, completed, cancelled
  final DateTime createdAt;

  Job({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerBusinessId,
    this.assignedBusinessId,
    this.transferToBusinessId,
    this.budgetAmount,
    this.awardedAmount,
    required this.status,
    required this.createdAt,
  });

  factory Job.fromMap(Map<String, dynamic> data, String id) {
    return Job(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      ownerBusinessId: data['ownerBusinessId'] ?? '',
      assignedBusinessId: data['assignedBusinessId'],
      transferToBusinessId: data['transferToBusinessId'],
      budgetAmount: (data['budgetAmount'] != null) ? (data['budgetAmount'] as num).toDouble() : null,
      awardedAmount: (data['awardedAmount'] != null) ? (data['awardedAmount'] as num).toDouble() : null,
      status: data['status'] ?? 'created',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'ownerBusinessId': ownerBusinessId,
      'assignedBusinessId': assignedBusinessId,
      'transferToBusinessId': transferToBusinessId,
      'budgetAmount': budgetAmount,
      'awardedAmount': awardedAmount,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Job copyWith({
    String? title,
    String? description,
    String? ownerBusinessId,
    String? assignedBusinessId,
    String? transferToBusinessId,
    double? budgetAmount,
    double? awardedAmount,
    String? status,
    DateTime? createdAt,
  }) {
    return Job(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      ownerBusinessId: ownerBusinessId ?? this.ownerBusinessId,
      assignedBusinessId: assignedBusinessId ?? this.assignedBusinessId,
      transferToBusinessId: transferToBusinessId ?? this.transferToBusinessId,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      awardedAmount: awardedAmount ?? this.awardedAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


