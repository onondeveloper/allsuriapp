import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job.dart';

class JobService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> createJob({
    required String ownerBusinessId,
    required String title,
    required String description,
    double? budgetAmount,
    String? location,
    String? category,
    String urgency = 'normal',
    double? commissionRate,
  }) async {
    try {
      final job = Job(
        title: title,
        description: description,
        ownerBusinessId: ownerBusinessId,
        budgetAmount: budgetAmount,
        location: location,
        category: category,
        urgency: urgency,
        commissionRate: commissionRate ?? 5.0, // Default 5% commission
        status: 'created',
        createdAt: DateTime.now(),
      );

      final response = await _supabase
          .from('jobs')
          .insert(job.toMap())
          .select()
          .single();

      return response['id'];
    } catch (e) {
      if (kDebugMode) {
        print('Error creating job: $e');
      }
      rethrow;
    }
  }

  Future<List<Job>> getJobs({String? status, String? category}) async {
    try {
      var query = _supabase
          .from('jobs')
          .select();

      if (status != null) {
        query = query.eq('status', status);
      }
      if (category != null) {
        query = query.eq('category', category);
      }

      final response = await query.order('created_at', ascending: false);
      return response.map((data) => Job.fromMap(data, data['id'])).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching jobs: $e');
      }
      rethrow;
    }
  }

  Future<Job?> getJob(String jobId) async {
    try {
      final response = await _supabase
          .from('jobs')
          .select()
          .eq('id', jobId)
          .single();

      return Job.fromMap(response, response['id']);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching job: $e');
      }
      return null;
    }
  }

  Future<void> requestTransfer({
    required String jobId,
    required String transferToBusinessId,
  }) async {
    try {
      await _supabase
          .from('jobs')
          .update({
            'transfer_to_business_id': transferToBusinessId,
            'status': 'pending_transfer',
          })
          .eq('id', jobId);
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting transfer: $e');
      }
      rethrow;
    }
  }

  Future<void> acceptTransfer({
    required String jobId,
    required String assigneeBusinessId,
    required double awardedAmount,
  }) async {
    try {
      await _supabase
          .from('jobs')
          .update({
            'assigned_business_id': assigneeBusinessId,
            'awarded_amount': awardedAmount,
            'status': 'assigned',
          })
          .eq('id', jobId);
    } catch (e) {
      if (kDebugMode) {
        print('Error accepting transfer: $e');
      }
      rethrow;
    }
  }

  Future<void> updateJobStatus({
    required String jobId,
    required String status,
  }) async {
    try {
      await _supabase
          .from('jobs')
          .update({'status': status})
          .eq('id', jobId);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating job status: $e');
      }
      rethrow;
    }
  }

  Future<List<Job>> getBusinessJobs(String businessId) async {
    try {
      final response = await _supabase
          .from('jobs')
          .select()
          .or('owner_business_id.eq.$businessId,assigned_business_id.eq.$businessId')
          .order('created_at', ascending: false);

      return response.map((data) => Job.fromMap(data, data['id'])).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching business jobs: $e');
      }
      rethrow;
    }
  }
}


