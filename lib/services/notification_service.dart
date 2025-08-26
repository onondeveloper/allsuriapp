import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';

class NotificationService {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<List<NotificationModel>> getNotifications(String userId) async {
    final rows = await _sb
        .from('notifications')
        .select()
        .eq('userid', userId)
        .order('createdat', ascending: false);
    return rows
        .map((r) => NotificationModel.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _sb
        .from('notifications')
        .update({'isread': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _sb
        .from('notifications')
        .update({'isread': true})
        .eq('userid', userId)
        .eq('isread', false);
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final rows = await _sb
          .from('notifications')
          .select('id')
          .eq('userid', userId)
          .eq('isread', false);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String? type,
    String? jobId,
    String? jobTitle,
    String? region,
    String? orderId,
    String? estimateId,
  }) async {
    await _sb.from('notifications').insert({
      'userid': userId,
      'title': title,
      'body': body,
      'type': type,
      'jobid': jobId,
      'jobtitle': jobTitle,
      'region': region,
      'orderId': orderId,
      'estimateId': estimateId,
      'isread': false,
      'createdat': DateTime.now().toIso8601String(),
    });
  }
}


