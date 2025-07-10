// TODO: 푸시 알림은 카카오 또는 자체 서버로 구현하세요.
// Firebase Messaging 관련 코드는 모두 삭제했습니다.

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/order.dart';
import 'package:flutter/material.dart';

class MessagingService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 로컬 알림 초기화
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error initializing messaging service: $e');
    }
  }

  // 알림 권한 요청 (임시 구현)
  Future<bool> requestPermission() async {
    try {
      // 임시로 항상 성공하도록 구현
      return true;
    } catch (e) {
      print('Error requesting notification permission: $e');
      return false;
    }
  }

  // 포그라운드 메시지 처리 (임시 구현)
  Future<void> _handleForegroundMessage(dynamic message) async {
    try {
      // 임시 구현 - 로컬 알림으로 표시
      await showLocalNotification(
        title: '새 메시지',
        body: '새로운 메시지가 도착했습니다.',
      );
    } catch (e) {
      print('Error handling foreground message: $e');
    }
  }

  // 백그라운드 메시지 처리 (임시 구현)
  static void _handleMessage(dynamic message) {
    try {
      print('Background message received: $message');
    } catch (e) {
      print('Error handling background message: $e');
    }
  }

  // 알림 탭 처리
  void _onNotificationTapped(NotificationResponse response) {
    try {
      print('Notification tapped: ${response.payload}');
      // 여기에 알림 탭 시 처리 로직 추가
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  // 로컬 알림 표시
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'allsuriapp_channel',
        '올수리 알림',
        channelDescription: '올수리 앱의 알림 채널',
        importance: Importance.max,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails();

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  // 토큰 가져오기 (임시 구현)
  Future<String?> getToken() async {
    try {
      // 임시로 고정 토큰 반환
      return 'temp_token_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }

  // 토픽 구독 (임시 구현)
  Future<void> subscribeToTopic(String topic) async {
    try {
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  // 토픽 구독 해제 (임시 구현)
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }

  // 알림 설정 가져오기 (임시 구현)
  Future<Map<String, bool>> getNotificationSettings() async {
    try {
      return {
        'new_estimates': true,
        'estimate_updates': true,
        'chat_messages': true,
        'system_notifications': true,
      };
    } catch (e) {
      print('Error getting notification settings: $e');
      return {};
    }
  }

  // 알림 설정 업데이트 (임시 구현)
  Future<void> updateNotificationSettings(Map<String, bool> settings) async {
    try {
      print('Updated notification settings: $settings');
    } catch (e) {
      print('Error updating notification settings: $e');
    }
  }

  // 새로운 견적 요청 알림 전송
  Future<void> sendNewRequestNotification(dynamic order) async {
    // 임시 구현: 실제 푸시 알림 대신 print
    print('새 견적 요청 알림: ${order.toString()}');
  }
} 