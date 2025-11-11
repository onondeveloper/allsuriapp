import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job.dart';
import 'notification_service.dart';

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
    List<String>? mediaUrls,
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
        mediaUrls: mediaUrls?.isNotEmpty == true ? mediaUrls : null,
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
      if (kDebugMode) {
        print('🔄 [JobService] 공사 이관 요청 시작: jobId=$jobId -> $transferToBusinessId');
      }

      final row = await _supabase
          .from('jobs')
          .update({
            'transfer_to_business_id': transferToBusinessId,
            'status': 'pending_transfer',
          })
          .eq('id', jobId)
          .select('owner_business_id')
          .maybeSingle();

      if (row == null) {
        if (kDebugMode) {
          print('⚠️ [JobService] 업데이트 결과가 없습니다 (jobId=$jobId).');
        }
        throw StateError('공사를 찾을 수 없습니다. 이미 처리되었을 수 있습니다.');
      }

      if (kDebugMode) {
        print('✅ [JobService] 공사 이관 상태 갱신 완료: $row');
      }

      // Notifications
      final ownerId = row['owner_business_id'] as String?;
      final notif = NotificationService();
      if (ownerId != null && ownerId.isNotEmpty) {
        await notif.sendNotification(
          userId: ownerId,
          title: '이관 요청 완료',
          body: '공사 이관 요청을 보냈습니다.',
        );
      }
      await notif.sendNotification(
        userId: transferToBusinessId,
        title: '공사 이관 요청',
        body: '새로운 공사 이관 요청이 도착했습니다.',
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [JobService] 공사 이관 요청 실패: $e');
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
      final row = await _supabase
          .from('jobs')
          .update({
            'assigned_business_id': assigneeBusinessId,
            'awarded_amount': awardedAmount,
            'status': 'assigned',
          })
          .eq('id', jobId)
          .select('owner_business_id, transfer_to_business_id')
          .single();

      final ownerId = row['owner_business_id'] as String?;
      final receiverId = row['transfer_to_business_id'] as String?;
      final notif = NotificationService();
      if (ownerId != null && ownerId.isNotEmpty) {
        await notif.sendNotification(
          userId: ownerId,
          title: '이관 완료',
          body: '요청한 공사가 이관 완료되었습니다.',
        );
      }
      if (receiverId != null && receiverId.isNotEmpty) {
        await notif.sendNotification(
          userId: receiverId,
          title: '공사를 받았습니다',
          body: '공사 이관을 수락했습니다.',
        );
      }
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
      final row = await _supabase
          .from('jobs')
          .update({'status': status})
          .eq('id', jobId)
          .select('owner_business_id, transfer_to_business_id, assigned_business_id')
          .single();

      final ownerId = row['owner_business_id'] as String?;
      final receiverId = row['transfer_to_business_id'] as String?;
      final assigneeId = row['assigned_business_id'] as String?;
      final notif = NotificationService();
      if (status == 'transfer_rejected') {
        if (ownerId != null && ownerId.isNotEmpty) {
          await notif.sendNotification(
            userId: ownerId,
            title: '이관 거절',
            body: '이관 요청이 거절되었습니다.',
          );
        }
      }
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


