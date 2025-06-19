import 'package:kakao_flutter_sdk_talk/kakao_flutter_sdk_talk.dart';

class KakaoChatService {
  static final KakaoChatService _instance = KakaoChatService._internal();

  factory KakaoChatService() {
    return _instance;
  }

  KakaoChatService._internal();

  Future<void> sendMessage({
    required String templateId,
    required Map<String, String> templateArgs,
  }) async {
    try {
      await TalkApi.instance.sendDefaultMessage(
        templateId: templateId,
        templateArgs: templateArgs,
      );
    } catch (error) {
      print('카카오톡 메시지 전송 실패: $error');
      throw error;
    }
  }

  Future<List<ChatRoom>> getChatRooms() async {
    try {
      final ChatRoomListResponse chatRooms = 
          await TalkApi.instance.getChatRooms();
      return chatRooms.elements;
    } catch (error) {
      print('채팅방 목록 조회 실패: $error');
      return [];
    }
  }

  Future<void> sendCustomMessage({
    required String roomId,
    required String message,
  }) async {
    try {
      await TalkApi.instance.sendCustomMessage(
        receiverChatRoomId: roomId,
        templateId: 'custom_message',
        templateArgs: {
          'message': message,
        },
      );
    } catch (error) {
      print('커스텀 메시지 전송 실패: $error');
      throw error;
    }
  }
} 