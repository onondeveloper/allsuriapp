import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class ChatService extends ChangeNotifier {
  final SupabaseClient _sb = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();

  // 기존 코드 호환: roomKey를 title로 저장하고, 실제 id는 DB에서 생성/기존 채팅방 재사용
  Future<String> createChatRoom(String roomKey, String customerId, String businessId, {String? estimateId}) async {
    return ensureChatRoom(customerId: customerId, businessId: businessId, title: roomKey, estimateId: estimateId);
  }

  Future<String> ensureChatRoom({
    required String customerId,
    required String businessId,
    String? estimateId, // 관련 엔티티 id(옵션)
    String? title,
  }) async {
    try {
      // 0) If caller passed a deterministic key (e.g., 'call_<listingId>'),
      // try to reuse a room whose title equals it, or id if it's a UUID.
      if (title != null && title.isNotEmpty) {
        try {
          final uuidPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
          if (uuidPattern.hasMatch(title)) {
            final byId = await _sb
                .from('chat_rooms')
                .select('id')
                .eq('id', title)
                .limit(1)
                .maybeSingle();
            if (byId != null && byId['id'] != null) {
              return byId['id'].toString();
            }
          }
          final byTitle = await _sb
              .from('chat_rooms')
              .select('id')
              .eq('title', title)
              .limit(1)
              .maybeSingle();
          if (byTitle != null && byTitle['id'] != null) {
            return byTitle['id'].toString();
          }
        } catch (_) {}
      }
      Map<String, dynamic>? existing;
      // Schema: customerid/businessid
      try {
        var q1 = _sb
            .from('chat_rooms')
            .select('id')
            .eq('customerid', customerId)
            .eq('businessid', businessId);
        if (estimateId != null && estimateId.isNotEmpty) {
          q1 = q1.eq('estimateid', estimateId);
        }
        existing = await q1.limit(1).maybeSingle();
      } catch (_) {
        existing = null;
      }
      if (existing != null && existing['id'] != null) {
        return existing['id'].toString();
      }

      final nowIso = DateTime.now().toIso8601String();
      // Insert with customerid/businessid schema
      try {
        final payloadA = <String, dynamic>{
          'customerid': customerId,
          'businessid': businessId,
          'active': true,
          'createdat': nowIso,
          // estimateid NOT NULL인 경우를 대비해 비워두지 않음
          if (estimateId != null && estimateId.isNotEmpty) 'estimateid': estimateId,
          if (title != null && title.isNotEmpty) 'title': title,
        };
        if (!payloadA.containsKey('estimateid')) {
          // DB가 NOT NULL이면 임시 UUID 생성 방지: 대신 participants+title 기반 중복을 허용하고,
          // 상위 호출부에서 반드시 estimateId를 전달하도록 유도
          throw PostgrestException(message: 'estimateid_required', code: '23502', details: 'estimateid is required', hint: null);
        }
        final insA = await _sb.from('chat_rooms').insert(payloadA).select('id').single();
        return insA['id'].toString();
      } catch (e) {
        debugPrint('insert chat_room failed: $e');
        rethrow;
      }
    } catch (e) {
      debugPrint('ensureChatRoom failed: $e');
      rethrow;
    }
  }

  // 메시지 전송 (임시 구현)
  Future<void> sendMessage(String chatRoomId, String message, String senderId) async {
    try {
      print('=== sendMessage 시작 ===');
      print('chatRoomId: $chatRoomId');
      print('message: $message');
      print('senderId: $senderId');
      
      // If chatRoomId is not a UUID, try to resolve to a UUID via chat_rooms
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(chatRoomId);
      String resolvedId = chatRoomId;
      
      print('isUuid: $isUuid');
      
      if (!isUuid) {
        print('UUID가 아님, chat_rooms에서 ID 확인 시도...');
        try {
          final existingRoom = await _sb
              .from('chat_rooms')
              .select('id')
              .eq('title', chatRoomId)
              .limit(1)
              .maybeSingle();
          
          if (existingRoom != null && existingRoom['id'] != null) {
            resolvedId = existingRoom['id'].toString();
            print('기존 채팅방 ID 찾음: $resolvedId');
          } else {
            print('기존 채팅방을 찾을 수 없음');
          }
        } catch (e) {
          print('기존 채팅방 검색 실패: $e');
        }
      }

      print('최종 resolvedId: $resolvedId');

      // 메시지 저장
      final nowIso = DateTime.now().toIso8601String();
      print('메시지 저장 시도...');
      print('테이블: messages');
      print('데이터: {roomid: $resolvedId, senderid: $senderId, text: $message, createdat: $nowIso}');
      
      final insertResult = await _sb.from('messages').insert({
        'roomid': resolvedId,
        'senderid': senderId,
        'text': message,
        'createdat': nowIso,
      }).select();
      
      print('메시지 저장 성공: $insertResult');

      // 채팅방 참가자 정보 가져오기
      print('채팅방 정보 가져오기 시도...');
      final chatRoom = await _sb
          .from('chat_rooms')
          .select('customerid, businessid, title')
          .eq('id', resolvedId)
          .single();
      
      print('채팅방 정보: $chatRoom');

      // 발신자 정보 가져오기
      print('발신자 프로필 가져오기 시도...');
      final senderProfile = await _getUserProfile(senderId);
      final senderName = senderProfile?['name'] ?? senderProfile?['businessname'] ?? '사용자';
      print('발신자 이름: $senderName');

      // 수신자 ID 결정 (발신자가 고객이면 사업자, 사업자면 고객)
      String recipientId;
      if (senderId == chatRoom['customerid']) {
        recipientId = chatRoom['businessid'];
        print('발신자가 고객, 수신자는 사업자: $recipientId');
      } else {
        recipientId = chatRoom['customerid'];
        print('발신자가 사업자, 수신자는 고객: $recipientId');
      }

      // 채팅 알림 전송
      print('채팅 알림 전송 시도...');
      await _notificationService.sendChatNotification(
        recipientUserId: recipientId,
        senderName: senderName,
        message: message,
        chatRoomId: resolvedId,
      );

      print('=== 메시지 전송 및 알림 완료 ===');
      print('chatRoomId: $resolvedId');
      print('수신자: $recipientId');
      print('발신자: $senderName');
      
    } catch (e) {
      print('=== sendMessage 실패 ===');
      print('에러: $e');
      print('에러 타입: ${e.runtimeType}');
      if (e is PostgrestException) {
        print('PostgrestException 상세:');
        print('  message: ${e.message}');
        print('  code: ${e.code}');
        print('  details: ${e.details}');
        print('  hint: ${e.hint}');
      }
      debugPrint('sendMessage failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String chatRoomId) async {
    try {
      final me = _sb.auth.currentUser?.id ?? '';
      final rows = await _sb
          .from('messages')
          .select()
          .eq('roomid', chatRoomId)
          .order('createdat', ascending: true);
      return rows.map((r) {
        final m = Map<String, dynamic>.from(r);
        final created = m['createdat'] ?? m['createdAt'] ?? m['created_at'];
        m['timestamp'] = DateTime.tryParse(created?.toString() ?? '') ?? DateTime.now();
        m['isFromMe'] = (m['senderid']?.toString() ?? m['senderId']?.toString() ?? m['sender_id']?.toString() ?? '') == me;
        m['text'] = (m['content'] ?? m['text'] ?? '').toString();
        return m;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> markChatRead(String chatRoomId) async {
    // Optional: implement unread tracking if schema supports it
    return;
  }

  // 채팅방 목록 가져오기 (임시 구현)
  Future<List<Map<String, dynamic>>> getChatRooms(String userId) async {
    try {
      final rows = await _sb
          .from('chat_rooms')
          .select('id, title, createdat, customerid, businessid, estimateid, active')
          .or('customerid.eq.$userId,businessid.eq.$userId')
          .eq('active', true)
          .order('createdat', ascending: false);
      final list = <Map<String, dynamic>>[];
      for (final r in rows) {
        final room = Map<String, dynamic>.from(r);
        final otherId = (room['customerid'] == userId) ? (room['businessid']?.toString() ?? '') : (room['customerid']?.toString() ?? '');
        if (otherId.isNotEmpty) {
          try {
            final u = await _sb.from('users').select('businessName, name').eq('id', otherId).maybeSingle();
            final displayName = (u != null && (u['businessName']?.toString().isNotEmpty == true))
                ? u['businessName'].toString()
                : (u != null ? (u['name']?.toString() ?? '상대방') : '상대방');
            room['displayName'] = displayName;
          } catch (_) {
            room['displayName'] = '상대방';
          }
        }
        // 최근 메시지
        try {
          final last = await _sb
              .from('messages')
              .select('content, text, createdat')
              .eq('roomid', room['id'])
              .order('createdat', ascending: false)
              .limit(1)
              .maybeSingle();
          if (last != null) {
            room['lastMessage'] = (last['content']?.toString() ?? last['text']?.toString() ?? '');
            room['lastMessageAt'] = last['createdat']?.toString();
          } else {
            room['lastMessage'] = '';
          }
        } catch (_) {
          room['lastMessage'] = '';
        }
        list.add(room);
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  // 채팅방 상세 (estimateid, participants 등)
  Future<Map<String, dynamic>?> getChatRoom(String chatRoomId) async {
    try {
      final row = await _sb
          .from('chat_rooms')
          .select()
          .eq('id', chatRoomId)
          .maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }

  // 메시지 전체 삭제
  Future<void> deleteMessages(String chatRoomId) async {
    await _sb.from('messages').delete().eq('roomid', chatRoomId);
  }

  // 채팅방 삭제 (소프트 삭제: active=false)
  Future<void> softDeleteChatRoom(String chatRoomId, String userId) async {
    await _sb
        .from('chat_rooms')
        .update({'active': false})
        .eq('id', chatRoomId)
        .or('customerid.eq.$userId,businessid.eq.$userId');
  }

  // 채팅방 활성화 (임시 구현)
  Future<void> activateChatRoom(String estimateId, String businessId) async {
    try {
      await _sb
          .from('chat_rooms')
          .update({'active': true})
          .eq('estimateid', estimateId)
          .eq('businessid', businessId);
    } catch (e) {
      rethrow;
    }
  }

  /// 사용자 프로필 정보 가져오기
  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    try {
      // 고객 프로필 확인
      final customerProfile = await _sb
          .from('customers')
          .select('name')
          .eq('id', userId)
          .maybeSingle();
      
      if (customerProfile != null) {
        return customerProfile;
      }

      // 사업자 프로필 확인
      final businessProfile = await _sb
          .from('businesses')
          .select('businessname')
          .eq('id', userId)
          .maybeSingle();
      
      if (businessProfile != null) {
        return businessProfile;
      }

      return null;
    } catch (e) {
      debugPrint('사용자 프로필 가져오기 실패: $e');
      return null;
    }
  }
} 