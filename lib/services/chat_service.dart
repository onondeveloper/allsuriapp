import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService extends ChangeNotifier {
  final SupabaseClient _sb = Supabase.instance.client;
  final dynamic _anonymousService;

  ChatService(this._anonymousService);

  // 채팅방 생성 (임시 구현)
  Future<String> createChatRoom(String estimateId, String customerId, String businessId) async {
    try {
      final id = 'chat_$estimateId';
      await _sb.from('chat_rooms').upsert({
        'id': id,
        'estimateId': estimateId,
        'customerId': customerId,
        'businessId': businessId,
        'createdAt': DateTime.now().toIso8601String(),
      });
      return id;
    } catch (e) {
      print('Error creating chat room: $e');
      rethrow;
    }
  }

  // 메시지 전송 (임시 구현)
  Future<void> sendMessage(String chatRoomId, String message, String senderId) async {
    try {
      await _sb.from('messages').insert({
        'roomId': chatRoomId,
        'senderId': senderId,
        'text': message,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // 채팅방 목록 가져오기 (임시 구현)
  Future<List<Map<String, dynamic>>> getChatRooms(String userId) async {
    try {
      final rows = await _sb
          .from('chat_rooms')
          .select()
          .or('customerId.eq.$userId,businessId.eq.$userId')
          .order('createdAt', ascending: false);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      print('Error getting chat rooms: $e');
      return [];
    }
  }

  // 채팅방 활성화 (임시 구현)
  Future<void> activateChatRoom(String estimateId, String businessId) async {
    try {
      await _sb
          .from('chat_rooms')
          .update({'active': true})
          .eq('estimateId', estimateId)
          .eq('businessId', businessId);
    } catch (e) {
      print('Error activating chat room: $e');
      rethrow;
    }
  }
} 