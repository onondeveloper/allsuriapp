import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ApiService extends ChangeNotifier {
  // 임시 API 기본 URL
  static const String baseUrl = 'https://api.allsuriapp.com';

  // GET 요청 (임시 구현)
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      // 임시로 더미 데이터 반환
      await Future.delayed(const Duration(milliseconds: 500)); // 네트워크 지연 시뮬레이션
      
      return {
        'success': true,
        'data': _getDummyData(endpoint),
        'message': 'Success',
      };
    } catch (e) {
      print('GET request error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // POST 요청 (임시 구현)
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    try {
      // 임시로 더미 응답 반환
      await Future.delayed(const Duration(milliseconds: 500)); // 네트워크 지연 시뮬레이션
      
      return {
        'success': true,
        'data': {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'createdAt': DateTime.now().toIso8601String(),
          ...data,
        },
        'message': 'Created successfully',
      };
    } catch (e) {
      print('POST request error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // PUT 요청 (임시 구현)
  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    try {
      // 임시로 더미 응답 반환
      await Future.delayed(const Duration(milliseconds: 300));
      
      return {
        'success': true,
        'data': {
          'id': endpoint.split('/').last,
          'updatedAt': DateTime.now().toIso8601String(),
          ...data,
        },
        'message': 'Updated successfully',
      };
    } catch (e) {
      print('PUT request error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // DELETE 요청 (임시 구현)
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      // 임시로 더미 응답 반환
      await Future.delayed(const Duration(milliseconds: 200));
      
      return {
        'success': true,
        'message': 'Deleted successfully',
      };
    } catch (e) {
      print('DELETE request error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // 파일 업로드 (임시 구현)
  Future<Map<String, dynamic>> uploadFile(String endpoint, File file) async {
    try {
      // 임시로 더미 응답 반환
      await Future.delayed(const Duration(milliseconds: 1000));
      
      return {
        'success': true,
        'data': {
          'url': 'https://example.com/uploads/${file.path.split('/').last}',
          'filename': file.path.split('/').last,
          'size': await file.length(),
        },
        'message': 'File uploaded successfully',
      };
    } catch (e) {
      print('File upload error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // 더미 데이터 생성
  Map<String, dynamic> _getDummyData(String endpoint) {
    if (endpoint.contains('/orders')) {
      return {
        'orders': [
          {
            'id': '1',
            'title': '에어컨 수리',
            'description': '에어컨이 작동하지 않습니다.',
            'status': 'pending',
            'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          },
          {
            'id': '2',
            'title': '배관 수리',
            'description': '물이 새고 있습니다.',
            'status': 'in_progress',
            'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          },
        ],
      };
    } else if (endpoint.contains('/estimates')) {
      return {
        'estimates': [
          {
            'id': '1',
            'orderId': '1',
            'technicianId': 'tech1',
            'price': 50000,
            'description': '에어컨 필터 교체 및 청소',
            'status': 'pending',
            'createdAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          },
        ],
      };
    } else if (endpoint.contains('/users')) {
      return {
        'users': [
          {
            'id': '1',
            'name': '홍길동',
            'email': 'hong@example.com',
            'role': 'customer',
          },
        ],
      };
    }
    
    return {'message': 'No data available'};
  }

  // 에러 처리
  void handleError(dynamic error) {
    if (kDebugMode) {
      print('API Error: $error');
    }
  }

  Future<Map<String, dynamic>> getNotificationSettings() async {
    // 임시 구현
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'new_estimate': true,
      'estimate_accepted': true,
      'estimate_rejected': true,
      'order_status_changed': true,
      'order_completed': true,
      'chat_message': true,
    };
  }

  Future<void> updateNotificationSettings(Map<String, bool> settings) async {
    // 임시 구현
    await Future.delayed(const Duration(milliseconds: 500));
    print('Notification settings updated: $settings');
  }

  // 기존 메서드들...
  Future<void> sendNotification(String userId, String title, String body) async {
    // 임시 구현
    await Future.delayed(const Duration(milliseconds: 300));
    print('Notification sent to $userId: $title - $body');
  }

  Future<List<Map<String, dynamic>>> getChatRooms() async {
    // 임시 채팅방 데이터
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      {
        'id': '1',
        'title': '수리 견적 문의',
        'lastMessage': '안녕하세요! 견적 요청해주셔서 감사합니다.',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
        'unreadCount': 1,
      },
      {
        'id': '2',
        'title': '에어컨 수리 요청',
        'lastMessage': '네, 언제 방문 가능하신가요?',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'unreadCount': 0,
      },
    ];
  }

  Future<List<Map<String, dynamic>>> getMessages(String chatRoomId) async {
    // 임시 메시지 데이터
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {
        'id': '1',
        'text': '안녕하세요! 견적 요청해주셔서 감사합니다.',
        'isFromMe': false,
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
      },
      {
        'id': '2',
        'text': '네, 언제 방문 가능하신가요?',
        'isFromMe': true,
        'timestamp': DateTime.now().subtract(const Duration(minutes: 3)),
      },
    ];
  }

  Future<void> sendMessage(String chatRoomId, String message) async {
    // 임시 구현
    await Future.delayed(const Duration(milliseconds: 200));
    print('Message sent to $chatRoomId: $message');
  }
}
