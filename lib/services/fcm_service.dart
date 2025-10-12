import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../firebase_options.dart';

/// Firebase Cloud Messaging 서비스
/// 실시간 푸시 알림을 처리하고 FCM 토큰을 관리합니다.
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _sb = Supabase.instance.client;
  
  // 로컬 알림 플러그인 (포그라운드 알림용)
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// FCM 초기화
  Future<void> initialize() async {
    try {
      print('🔔 FCM 초기화 시작...');

      // Firebase 초기화 확인
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // 알림 권한 요청
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ FCM 권한 승인됨');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('⚠️ FCM 임시 권한 승인됨');
      } else {
        print('❌ FCM 권한 거부됨');
        return;
      }

      // FCM 토큰 가져오기
      _fcmToken = await _messaging.getToken();
      print('🔑 FCM 토큰: $_fcmToken');

      // 로컬 알림 초기화
      await _initializeLocalNotifications();

      // 메시지 핸들러 설정
      _setupMessageHandlers();

      // 토큰 갱신 리스너
      _messaging.onTokenRefresh.listen((newToken) {
        print('🔄 FCM 토큰 갱신: $newToken');
        _fcmToken = newToken;
        // 서버에 토큰 업데이트 (로그인 후 자동으로 업데이트됨)
      });

      print('✅ FCM 초기화 완료');
    } catch (e) {
      print('❌ FCM 초기화 실패: $e');
      print('   Firebase 설정을 확인하세요:');
      print('   1. google-services.json (Android)');
      print('   2. GoogleService-Info.plist (iOS)');
      print('   3. Firebase Console에서 앱이 등록되어 있는지 확인');
      rethrow; // 에러를 다시 던져서 main.dart에서 catch하도록 함
    }
  }

  /// 로컬 알림 초기화 (포그라운드 알림용)
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print('📱 로컬 알림 클릭: ${details.payload}');
        _handleNotificationTap(details.payload);
      },
    );
  }

  /// 메시지 핸들러 설정
  void _setupMessageHandlers() {
    // 포그라운드 메시지 (앱이 실행 중일 때)
    FirebaseMessaging.onMessage.listen((message) {
      print('📩 포그라운드 메시지 수신: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // 백그라운드 메시지에서 앱 열림
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('🚀 백그라운드 메시지에서 앱 열림: ${message.notification?.title}');
      _handleNotificationTap(jsonEncode(message.data));
    });

    // 앱이 종료된 상태에서 알림 탭으로 앱 시작
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        print('🌟 종료 상태에서 알림으로 앱 시작: ${message.notification?.title}');
        _handleNotificationTap(jsonEncode(message.data));
      }
    });
  }

  /// 포그라운드에서 로컬 알림 표시
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'allsuri_notifications',
      '올수리 알림',
      channelDescription: '올수리 서비스의 일반 알림',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// 알림 탭 처리
  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      
      print('🔔 알림 타입: $type, 데이터: $data');
      
      // TODO: 타입별로 적절한 화면으로 이동
      // 예: Navigator.pushNamed(context, '/route', arguments: data);
      // 실제 구현은 앱의 라우팅 시스템에 맞게 조정 필요
      
    } catch (e) {
      print('❌ 알림 데이터 파싱 실패: $e');
    }
  }

  /// FCM 토큰을 Supabase에 저장
  Future<void> saveFCMToken(String userId) async {
    if (_fcmToken == null) {
      print('⚠️ FCM 토큰이 없습니다.');
      return;
    }

    try {
      print('💾 FCM 토큰 저장 중: $userId');
      
      await _sb
          .from('users')
          .update({'fcm_token': _fcmToken})
          .eq('id', userId);

      print('✅ FCM 토큰 저장 완료');
    } catch (e) {
      print('❌ FCM 토큰 저장 실패: $e');
    }
  }

  /// FCM 토큰 삭제 (로그아웃 시)
  Future<void> deleteFCMToken(String userId) async {
    try {
      print('🗑️ FCM 토큰 삭제 중: $userId');
      
      await _sb
          .from('users')
          .update({'fcm_token': null})
          .eq('id', userId);

      print('✅ FCM 토큰 삭제 완료');
    } catch (e) {
      print('❌ FCM 토큰 삭제 실패: $e');
    }
  }

  /// 백그라운드 메시지 핸들러 (앱 외부에서 처리)
  static Future<void> backgroundMessageHandler(RemoteMessage message) async {
    print('🌙 백그라운드 메시지 수신: ${message.notification?.title}');
    // 여기서는 Supabase에 알림 저장 등의 작업만 가능
    // UI 작업은 불가능
  }
}

/// 백그라운드 메시지 핸들러 (최상위 함수여야 함)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FCMService.backgroundMessageHandler(message);
}

