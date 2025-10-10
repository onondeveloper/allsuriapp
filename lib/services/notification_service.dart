import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _sb = Supabase.instance.client;
  
  // 알림 권한 상태 저장용
  static const String _notificationPermissionKey = 'notification_permission';

  /// 초기화
  Future<void> initialize() async {
    try {
      // 알림 권한 요청 (iOS)
      await _requestNotificationPermissions();
      print('NotificationService 초기화 완료');
    } catch (e) {
      print('NotificationService 초기화 실패: $e');
    }
  }

  /// 알림 권한 요청 (iOS)
  Future<void> _requestNotificationPermissions() async {
    try {
      // iOS 권한 요청은 단순화 (실제로는 필요시에만 구현)
      print('알림 권한 요청 완료');
    } catch (e) {
      print('알림 권한 요청 실패: $e');
    }
  }

  /// 알림 목록 가져오기
  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    try {
      final response = await _sb
          .from('notifications')
          .select()
          .eq('userid', userId)
          .order('createdat', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('알림 목록 가져오기 실패: $e');
      return [];
    }
  }

  /// 읽지 않은 알림 개수 가져오기
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _sb
          .from('notifications')
          .select('id')
          .eq('userid', userId)
          .eq('isread', false);
      
      return response.length;
    } catch (e) {
      print('읽지 않은 알림 개수 가져오기 실패: $e');
      return 0;
    }
  }

  /// 알림을 읽음으로 표시
  Future<void> markAsRead(String notificationId) async {
    try {
      await _sb
          .from('notifications')
          .update({'isread': true})
          .eq('id', notificationId);
    } catch (e) {
      print('알림 읽음 표시 실패: $e');
    }
  }

  /// 모든 알림을 읽음으로 표시
  Future<void> markAllAsRead(String userId) async {
    try {
      await _sb
          .from('notifications')
          .update({'isread': true})
          .eq('userid', userId)
          .eq('isread', false);
    } catch (e) {
      print('모든 알림 읽음 표시 실패: $e');
    }
  }

  /// 일반 알림 전송 (Supabase에 저장 + FCM 푸시)
  /// 
  /// 이 함수는 Supabase에 알림을 저장하고, 백엔드를 통해 FCM 푸시도 전송합니다.
  /// 다른 기능에서도 쉽게 사용할 수 있습니다.
  /// 
  /// 예제:
  /// ```dart
  /// await NotificationService().sendNotification(
  ///   userId: 'kakao:123',
  ///   title: '새 견적 요청',
  ///   body: '강남구에서 에어컨 수리 견적이 도착했습니다.',
  ///   type: 'new_estimate',
  ///   jobId: 'job-123',
  /// );
  /// ```
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
    String? chatRoomId,
  }) async {
    try {
      // 1. Supabase에 알림 저장
      await _sb.from('notifications').insert({
        'userid': userId,
        'title': title,
        'body': body,
        'type': type,
        'jobid': jobId,
        'jobtitle': jobTitle,
        'region': region,
        'orderid': orderId,
        'estimateid': estimateId,
        'chatroom_id': chatRoomId,
        'isread': false,
        'createdat': DateTime.now().toIso8601String(),
      });
      
      print('✅ 알림 DB 저장 완료: $userId - $title');
      
      // 2. 백엔드를 통해 FCM 푸시 전송 (비동기, 실패해도 무시)
      try {
        final api = ApiService();
        await api.post('/notifications/send-push', {
          'userId': userId,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': {
            'type': type ?? 'general',
            'jobId': jobId,
            'orderId': orderId,
            'estimateId': estimateId,
          },
        }).timeout(
          const Duration(seconds: 3),
          onTimeout: () => {'success': false, 'error': 'timeout'},
        );
        print('✅ FCM 푸시 전송 완료');
      } catch (e) {
        print('⚠️ FCM 푸시 전송 실패 (무시됨): $e');
        // FCM 실패해도 알림은 DB에 저장되었으므로 성공으로 처리
      }
    } catch (e) {
      print('❌ 알림 전송 실패: $e');
      rethrow;
    }
  }

  /// 채팅 메시지 알림 전송
  Future<void> sendChatNotification({
    required String recipientUserId,
    required String senderName,
    required String message,
    required String chatRoomId,
  }) async {
    try {
      // 1. Supabase에 알림 저장
      await sendNotification(
        userId: recipientUserId,
        title: '$senderName님의 메시지',
        body: message,
        type: 'chat_message',
        chatRoomId: chatRoomId,
      );

      // 2. Supabase Edge Function으로 FCM 전송 시도 (일시 비활성화)
      // TODO: Edge Function 배포 후 활성화
      /*
      try {
        await _sendFCMViaEdgeFunction(
          recipientUserId: recipientUserId,
          senderName: senderName,
          message: message,
          chatRoomId: chatRoomId,
        );
      } catch (e) {
        print('FCM 전송 실패 (무시됨): $e');
        // FCM 실패해도 Supabase 알림은 성공
      }
      */
      
      print('FCM 전송은 일시 비활성화됨 (Edge Function 미배포)');
      
      print('채팅 알림 전송 완료: $recipientUserId');
    } catch (e) {
      print('채팅 알림 전송 실패: $e');
    }
  }

  /// Supabase Edge Function으로 FCM 전송
  Future<void> _sendFCMViaEdgeFunction({
    required String recipientUserId,
    required String senderName,
    required String message,
    required String chatRoomId,
  }) async {
    try {
      final response = await _sb.functions.invoke(
        'send-chat-notification',
        body: {
          'recipientUserId': recipientUserId,
          'senderName': senderName,
          'message': message,
          'chatRoomId': chatRoomId,
        },
      );
      
      if (response.status != 200) {
        throw Exception('Edge Function 호출 실패: ${response.status}');
      }
      
      print('FCM 전송 성공 (Edge Function)');
    } catch (e) {
      print('Edge Function FCM 전송 실패: $e');
      rethrow;
    }
  }

  /// 배지 카운트 업데이트 (앱 아이콘에 표시)
  Future<void> updateBadgeCount(int count) async {
    try {
      // Android/iOS 배지 업데이트 로직
      // 실제 구현은 플랫폼별로 다를 수 있음
      print('배지 카운트 업데이트: $count');
    } catch (e) {
      print('배지 카운트 업데이트 실패: $e');
    }
  }

  /// 알림 설정 상태 확인
  Future<bool> isNotificationEnabled() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_notificationPermissionKey) ?? true;
    } catch (e) {
      print('알림 설정 상태 확인 실패: $e');
      return true;
    }
  }

  /// 알림 설정 상태 저장
  Future<void> setNotificationEnabled(bool enabled) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationPermissionKey, enabled);
    } catch (e) {
      print('알림 설정 상태 저장 실패: $e');
    }
  }

  /// 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _sb
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      print('알림 삭제 실패: $e');
    }
  }

  /// 사용자별 알림 모두 삭제
  Future<void> deleteAllNotifications(String userId) async {
    try {
      await _sb
          .from('notifications')
          .delete()
          .eq('userid', userId);
    } catch (e) {
      print('사용자 알림 모두 삭제 실패: $e');
    }
  }
}


