import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification.dart' as app_notification;

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 사용자의 알림 목록 가져오기
  Future<List<app_notification.NotificationModel>> getNotifications(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => app_notification.NotificationModel.fromMap({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  // 알림 읽음 처리
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // 모든 알림 읽음 처리
  Future<void> markAllAsRead(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // 새 알림 생성
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? orderId,
    String? estimateId,
  }) async {
    try {
      final notification = app_notification.NotificationModel(
        id: '',
        title: title,
        message: message,
        type: type,
        orderId: orderId,
        estimateId: estimateId,
        createdAt: DateTime.now(),
        userId: userId,
      );

      await _firestore
          .collection('notifications')
          .add(notification.toMap());
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // 읽지 않은 알림 개수 가져오기
  Future<int> getUnreadCount(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // 견적 제안 알림 생성
  Future<void> createEstimateNotification({
    required String customerId,
    required String technicianName,
    required String orderTitle,
    String? orderId,
    String? estimateId,
  }) async {
    await createNotification(
      userId: customerId,
      title: '새로운 견적 제안',
      message: '$technicianName님이 "$orderTitle"에 대한 견적을 제안했습니다.',
      type: 'estimate',
      orderId: orderId,
      estimateId: estimateId,
    );
  }

  // 견적 선택 알림 생성
  Future<void> createEstimateSelectedNotification({
    required String technicianId,
    required String customerName,
    required String orderTitle,
    String? orderId,
    String? estimateId,
  }) async {
    await createNotification(
      userId: technicianId,
      title: '견적이 선택되었습니다',
      message: '$customerName님이 "$orderTitle"에 대한 귀하의 견적을 선택했습니다.',
      type: 'estimate_selected',
      orderId: orderId,
      estimateId: estimateId,
    );
  }

  // 주문 상태 변경 알림 생성
  Future<void> createOrderStatusNotification({
    required String userId,
    required String orderTitle,
    required String status,
    String? orderId,
  }) async {
    String message = '';
    switch (status) {
      case 'completed':
        message = '"$orderTitle" 주문이 완료되었습니다.';
        break;
      case 'in_progress':
        message = '"$orderTitle" 주문이 진행 중입니다.';
        break;
      default:
        message = '"$orderTitle" 주문 상태가 변경되었습니다.';
    }

    await createNotification(
      userId: userId,
      title: '주문 상태 변경',
      message: message,
      type: 'order_status',
      orderId: orderId,
    );
  }
} 