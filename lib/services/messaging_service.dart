// TODO: 푸시 알림은 카카오 또는 자체 서버로 구현하세요.
// Firebase Messaging 관련 코드는 모두 삭제했습니다.

import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MessagingService {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> initialize() async {
    // Initialize local notifications
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        '중요 알림',
        description: '견적 요청, 수락 등 중요한 알림을 위한 채널입니다.',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Get FCM token and save it
    final token = await _storage.read(key: 'fcm_token');
    if (token != null) {
      // TODO: Send token to backend
    }

    // Listen for token refresh
    _localNotifications.onDidReceiveBackgroundNotificationResponse.listen((response) async {
      await _handleBackgroundMessage(response.payload);
    });
  }

  void _onNotificationTapped(NotificationResponse response) {
    // TODO: Handle notification tap
    final payload = response.payload;
    if (payload != null) {
      // Navigate to appropriate screen based on payload
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    final data = message.data;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            '중요 알림',
            channelDescription: '견적 요청, 수락 등 중요한 알림을 위한 채널입니다.',
            icon: android?.smallIcon,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: data['route'],
      );
    }
  }

  void _handleMessage(RemoteMessage message) {
    final data = message.data;
    // TODO: Handle message data (e.g., navigate to specific screen)
  }

  Future<String?> getFCMToken() async {
    return await _storage.read(key: 'fcm_token');
  }

  Future<void> subscribeToTopic(String topic) async {
    // TODO: Implement topic subscription
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    // TODO: Implement topic unsubscription
  }

  Future<void> _handleBackgroundMessage(String? payload) async {
    // TODO: Handle background message
  }
} 