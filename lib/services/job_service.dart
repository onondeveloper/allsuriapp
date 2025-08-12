import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/job.dart';

class JobService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createJob({
    required String ownerBusinessId,
    required String title,
    required String description,
    double? budgetAmount,
  }) async {
    final docRef = _firestore.collection('jobs').doc();
    final job = Job(
      id: docRef.id,
      title: title,
      description: description,
      ownerBusinessId: ownerBusinessId,
      budgetAmount: budgetAmount,
      status: 'created',
      createdAt: DateTime.now(),
    );
    await docRef.set(job.toMap());
    return docRef.id;
  }

  Future<void> requestTransfer({
    required String jobId,
    required String transferToBusinessId,
  }) async {
    await _firestore.collection('jobs').doc(jobId).update({
      'transferToBusinessId': transferToBusinessId,
      'status': 'pending_transfer',
    });
  }

  Future<void> acceptTransfer({
    required String jobId,
    required String assigneeBusinessId,
    required double awardedAmount,
  }) async {
    await _firestore.collection('jobs').doc(jobId).update({
      'assignedBusinessId': assigneeBusinessId,
      'awardedAmount': awardedAmount,
      'status': 'assigned',
    });
  }
}


