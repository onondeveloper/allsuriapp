import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';

class NotificationService {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<List<NotificationModel>> getNotifications(String userId) async {
    final rows = await _sb
        .from('notifications')
        .select()
        .eq('userId', userId)
        .order('createdAt', ascending: false);
    return rows
        .map((r) => NotificationModel.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _sb
        .from('notifications')
        .update({'isRead': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _sb
        .from('notifications')
        .update({'isRead': true})
        .eq('userId', userId)
        .eq('isRead', false);
  }

  Future<int> getUnreadCount(String userId) async {
    final rows = await _sb
        .from('notifications')
        .select('id')
        .eq('userId', userId)
        .eq('isRead', false);
    return rows.length;
  }
}


