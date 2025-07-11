import 'package:flutter/foundation.dart';

class ChatService extends ChangeNotifier {
  final dynamic _anonymousService;

  ChatService(this._anonymousService);

  // 채팅방 생성 (임시 구현)
  Future<String> createChatRoom(String estimateId, String customerId, String businessId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      return 'chat_room_$estimateId';
    } catch (e) {
      print('Error creating chat room: $e');
      rethrow;
    }
  }

  // 메시지 전송 (임시 구현)
  Future<void> sendMessage(String chatRoomId, String message, String senderId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      print('Message sent to $chatRoomId: $message');
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // 채팅방 목록 가져오기 (임시 구현)
  Future<List<Map<String, dynamic>>> getChatRooms(String userId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      return [];
    } catch (e) {
      print('Error getting chat rooms: $e');
      return [];
    }
  }

  // 채팅방 활성화 (임시 구현)
  Future<void> activateChatRoom(String estimateId, String businessId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      print('Chat room activated for estimate: $estimateId, business: $businessId');
    } catch (e) {
      print('Error activating chat room: $e');
      rethrow;
    }
  }
} 