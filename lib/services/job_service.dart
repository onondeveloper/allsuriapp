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
    required String requesterBusinessId,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 [JobService] 공사 이관 요청 시작: jobId=$jobId -> $transferToBusinessId (요청자: $requesterBusinessId)');
      }

      final rows = await _supabase
          .from('jobs')
          .update({
            'transfer_to_business_id': transferToBusinessId,
            'status': 'pending_transfer',
          })
          .eq('id', jobId)
          .eq('owner_business_id', requesterBusinessId)
          .select('owner_business_id')
          .limit(1);

      if (rows.isEmpty) {
        if (kDebugMode) {
          print('⚠️ [JobService] 업데이트된 행이 없습니다 (jobId=$jobId, requester=$requesterBusinessId).');
        }
        throw StateError('공사를 찾을 수 없거나 이관 권한이 없습니다.');
      }

      final row = rows.first;

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
          .select('owner_business_id, transfer_to_business_id, assigned_business_id, title')
          .single();

      final ownerId = row['owner_business_id'] as String?;
      final receiverId = row['transfer_to_business_id'] as String?;
      final assigneeId = row['assigned_business_id'] as String?;
      final jobTitle = row['title'] as String? ?? '공사';
      
      final notif = NotificationService();
      
      if (status == 'transfer_rejected') {
        if (ownerId != null && ownerId.isNotEmpty) {
          await notif.sendNotification(
            userId: ownerId,
            title: '이관 거절',
            body: '이관 요청이 거절되었습니다.',
          );
        }
      } else if (status == 'cancelled') {
        // 공사가 취소된 경우 관련 당사자들에게 알림
        if (ownerId != null && ownerId.isNotEmpty) {
          await notif.sendNotification(
            userId: ownerId,
            title: '공사 취소됨',
            body: '[$jobTitle] 공사가 취소되었습니다.',
          );
        }
        if (assigneeId != null && assigneeId.isNotEmpty) {
          await notif.sendNotification(
            userId: assigneeId,
            title: '공사 취소됨',
            body: '[$jobTitle] 공사가 취소되었습니다.',
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

  /// 공사 취소 처리 (사업자용)
  /// - 마켓플레이스 리스팅도 함께 취소 처리
  Future<void> cancelJobByAssignee(String jobId, String listingId) async {
    try {
      // 1. 공사 상태 취소로 변경
      await _supabase
          .from('jobs')
          .update({'status': 'cancelled'})
          .eq('id', jobId);

      // 2. 마켓플레이스 리스팅 상태 취소로 변경
      await _supabase
          .from('marketplace_listings')
          .update({'status': 'cancelled'})
          .eq('id', listingId);

      // 3. 알림 전송은 updateJobStatus 내부 로직 활용을 위해 재호출하거나 직접 구현
      // 여기서는 명시적으로 호출
      await updateJobStatus(jobId: jobId, status: 'cancelled');
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ [JobService] 공사 취소 실패: $e');
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


