import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService extends ChangeNotifier {
  final SupabaseClient _sb = Supabase.instance.client;

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
      // If chatRoomId is not a UUID, try to resolve to a UUID via chat_rooms
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(chatRoomId);
      String resolvedId = chatRoomId;
      if (!isUuid) {
        try {
          // id == chatRoomId
          final byId = await _sb.from('chat_rooms').select('id').eq('id', chatRoomId).limit(1).maybeSingle();
          if (byId != null && byId['id'] != null && byId['id'].toString().length == 36) {
            resolvedId = byId['id'].toString();
          } else {
            // title == chatRoomId
            final byTitle = await _sb.from('chat_rooms').select('id').eq('title', chatRoomId).limit(1).maybeSingle();
            if (byTitle != null && byTitle['id'] != null && byTitle['id'].toString().length == 36) {
              resolvedId = byTitle['id'].toString();
            } else if (chatRoomId.startsWith('call_')) {
              final listingId = chatRoomId.substring(5);
              final byListing = await _sb.from('chat_rooms').select('id').eq('listingid', listingId).limit(1).maybeSingle();
              if (byListing != null && byListing['id'] != null && byListing['id'].toString().length == 36) {
                resolvedId = byListing['id'].toString();
              }
            }
          }
        } catch (_) {}
      }

      // messages 테이블에 우선 content 컬럼으로 시도, 실패 시 text 컬럼으로 재시도
      final now = DateTime.now().toIso8601String();
      try {
        await _sb.from('messages').insert({
          'roomid': resolvedId,
          'senderid': senderId,
          'content': message,
          'createdat': now,
        });
        return;
      } catch (_) {}
      await _sb.from('messages').insert({
        'roomid': resolvedId,
        'senderid': senderId,
        'text': message,
        'createdat': now,
      });
    } catch (e) {
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
          .select('id, title, createdat, customerid, businessid, estimateid')
          .or('customerid.eq.$userId,businessid.eq.$userId')
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
} 