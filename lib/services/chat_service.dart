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
    String? estimateId, // 견적서 ID (옵션)
    String? listingId, // 오더 마켓플레이스 ID (옵션)
    String? title,
  }) async {
    try {
      debugPrint('🔍 [ensureChatRoom] 채팅방 생성/조회 시작');
      debugPrint('   customerId: $customerId, businessId: $businessId');
      debugPrint('   estimateId: $estimateId, listingId: $listingId');
      
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
              debugPrint('✅ [ensureChatRoom] 기존 채팅방 찾음 (ID)');
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
            debugPrint('✅ [ensureChatRoom] 기존 채팅방 찾음 (Title)');
            return byTitle['id'].toString();
          }
        } catch (_) {}
      }
      
      Map<String, dynamic>? existing;
      // Schema: participant_a/participant_b 우선, 없으면 customerid/businessid
      try {
        debugPrint('🔍 [ensureChatRoom] 기존 채팅방 검색 (participants)');
        var q1 = _sb
            .from('chat_rooms')
            .select('id')
            .or('and(participant_a.eq.$customerId,participant_b.eq.$businessId),and(participant_a.eq.$businessId,participant_b.eq.$customerId)');
        
        // listingId가 있으면 listingId로 필터링
        if (listingId != null && listingId.isNotEmpty) {
          q1 = q1.eq('listingid', listingId);
        }
        // estimateId가 있으면 estimateId로 필터링
        else if (estimateId != null && estimateId.isNotEmpty) {
          q1 = q1.eq('estimateid', estimateId);
        }
        
        existing = await q1.limit(1).maybeSingle();
      } catch (e) {
        debugPrint('⚠️ [ensureChatRoom] participants 검색 실패: $e');
        // Fallback: customerid/businessid로 검색
        try {
          var q2 = _sb
              .from('chat_rooms')
              .select('id')
              .eq('customerid', customerId)
              .eq('businessid', businessId);
          if (listingId != null && listingId.isNotEmpty) {
            q2 = q2.eq('listingid', listingId);
          } else if (estimateId != null && estimateId.isNotEmpty) {
            q2 = q2.eq('estimateid', estimateId);
          }
          existing = await q2.limit(1).maybeSingle();
        } catch (_) {
          existing = null;
        }
      }
      
      if (existing != null && existing['id'] != null) {
        debugPrint('✅ [ensureChatRoom] 기존 채팅방 찾음: ${existing['id']}');
        return existing['id'].toString();
      }

      final nowIso = DateTime.now().toIso8601String();
      // Insert with both schemas (호환성 유지)
      try {
        debugPrint('🆕 [ensureChatRoom] 새 채팅방 생성');
        final payloadA = <String, dynamic>{
          // 새로운 스키마
          'participant_a': customerId,
          'participant_b': businessId,
          // 기존 스키마 (호환성)
          'customerid': customerId,
          'businessid': businessId,
          'active': true,
          'createdat': nowIso,
          // 오더 시스템인 경우 listingId, 견적 시스템인 경우 estimateId
          if (listingId != null && listingId.isNotEmpty) 'listingid': listingId,
          if (estimateId != null && estimateId.isNotEmpty) 'estimateid': estimateId,
          if (title != null && title.isNotEmpty) 'title': title,
        };
        
        debugPrint('   Payload: $payloadA');
        final insA = await _sb.from('chat_rooms').insert(payloadA).select('id').single();
        debugPrint('✅ [ensureChatRoom] 새 채팅방 생성 완료: ${insA['id']}');
        return insA['id'].toString();
      } catch (e) {
        debugPrint('❌ [ensureChatRoom] 채팅방 생성 실패: $e');
        rethrow;
      }
    } catch (e) {
      debugPrint('❌ [ensureChatRoom] 전체 프로세스 실패: $e');
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
      print('테이블: chat_messages');
      print('데이터: {room_id: $resolvedId, sender_id: $senderId, content: $message, createdat: $nowIso}');
      
      final insertResult = await _sb.from('chat_messages').insert({
        'room_id': resolvedId,
        'sender_id': senderId,
        'content': message,
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

      // 채팅 알림 전송 (실패해도 메시지는 성공으로 처리)
      print('채팅 알림 전송 시도...');
      try {
        await _notificationService.sendChatNotification(
          recipientUserId: recipientId,
          senderName: senderName,
          message: message,
          chatRoomId: resolvedId,
        );
        print('✅ 채팅 알림 전송 성공');
      } catch (notifError) {
        print('⚠️ 채팅 알림 전송 실패 (무시됨): $notifError');
        // 알림 실패해도 메시지는 저장되었으므로 계속 진행
      }

      print('=== 메시지 전송 완료 ===');
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
          .from('chat_messages')
          .select()
          .eq('room_id', chatRoomId)
          .order('createdat', ascending: true);
      return rows.map((r) {
        final m = Map<String, dynamic>.from(r);
        final created = m['createdat'] ?? m['createdAt'] ?? m['created_at'];
        m['timestamp'] = DateTime.tryParse(created?.toString() ?? '') ?? DateTime.now();
        m['isFromMe'] = (m['sender_id']?.toString() ?? m['senderid']?.toString() ?? m['senderId']?.toString() ?? '') == me;
        m['text'] = (m['content'] ?? m['text'] ?? '').toString();
        return m;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 채팅방을 읽음 처리 (현재 사용자의 last_read_at 업데이트)
  Future<void> markChatRead(String chatRoomId, String userId) async {
    try {
      debugPrint('📖 [ChatService] 채팅 읽음 처리: roomId=$chatRoomId, userId=$userId');
      
      // 채팅방 정보 가져오기
      final room = await _sb
          .from('chat_rooms')
          .select('participant_a, participant_b')
          .eq('id', chatRoomId)
          .maybeSingle();
      
      if (room == null) {
        debugPrint('   ⚠️ 채팅방을 찾을 수 없음');
        return;
      }
      
      // 현재 사용자가 participant_a인지 participant_b인지 확인
      final isParticipantA = room['participant_a']?.toString() == userId;
      final fieldToUpdate = isParticipantA 
          ? 'participant_a_last_read_at' 
          : 'participant_b_last_read_at';
      
      // 현재 시간으로 업데이트
      await _sb
          .from('chat_rooms')
          .update({fieldToUpdate: DateTime.now().toIso8601String()})
          .eq('id', chatRoomId);
      
      debugPrint('   ✅ 읽음 처리 완료: $fieldToUpdate');
    } catch (e) {
      debugPrint('   ❌ 읽음 처리 실패: $e');
    }
  }

  // 채팅방 목록 가져오기 (최적화 버전)
  Future<List<Map<String, dynamic>>> getChatRooms(String userId) async {
    try {
      debugPrint('🔍 [ChatService] 채팅방 목록 로드: userId=$userId');
      final startTime = DateTime.now();
      
      // 1. 채팅방 정보 가져오기
      final rows = await _sb
          .from('chat_rooms')
          .select('id, title, createdat, customerid, businessid, participant_a, participant_b, estimateid, listingid, active, participant_a_last_read_at, participant_b_last_read_at')
          .or('customerid.eq.$userId,businessid.eq.$userId,participant_a.eq.$userId,participant_b.eq.$userId')
          .eq('active', true)
          .order('createdat', ascending: false);
      
      debugPrint('✅ [ChatService] ${rows.length}개 채팅방 조회 완료');
      
      if (rows.isEmpty) return [];
      
      // 2. 모든 상대방 ID 수집
      final otherUserIds = <String>{};
      final roomMap = <String, Map<String, dynamic>>{};
      
      for (final r in rows) {
        final room = Map<String, dynamic>.from(r);
        roomMap[room['id']] = room;
        
        String otherId = '';
        if (room['participant_a']?.toString() == userId) {
          otherId = room['participant_b']?.toString() ?? '';
        } else if (room['participant_b']?.toString() == userId) {
          otherId = room['participant_a']?.toString() ?? '';
        } else if (room['customerid']?.toString() == userId) {
          otherId = room['businessid']?.toString() ?? '';
        } else if (room['businessid']?.toString() == userId) {
          otherId = room['customerid']?.toString() ?? '';
        }
        
        if (otherId.isNotEmpty) {
          otherUserIds.add(otherId);
          room['_otherId'] = otherId;
        }
      }
      
      // 3. 모든 사용자 정보 병렬로 가져오기
      final userMap = <String, Map<String, dynamic>>{};
      if (otherUserIds.isNotEmpty) {
        final userFutures = otherUserIds.map((id) {
          return _sb
              .from('users')
              .select('id, businessname, name')
              .eq('id', id)
              .maybeSingle()
              .then((user) {
            if (user != null) {
              userMap[user['id']] = user;
            }
          }).catchError((e) {
            debugPrint('   ⚠️ 사용자 정보 조회 실패 ($id): $e');
          });
        }).toList();
        
        await Future.wait(userFutures);
      }
      
      // 4. 병렬로 최근 메시지와 읽지 않은 메시지 수 가져오기
      final futures = <Future>[];
      
      for (final room in roomMap.values) {
        // 사용자 이름 설정
        final otherId = room['_otherId'];
        if (otherId != null && userMap.containsKey(otherId)) {
          final user = userMap[otherId];
          room['displayName'] = user?['businessname']?.toString() ?? user?['name']?.toString() ?? '상대방';
        } else {
          room['displayName'] = room['title']?.toString() ?? '채팅';
        }
        
        // 오더 제목 설정 (저장된 값 사용)
        final savedTitle = room['title']?.toString();
        if (savedTitle != null && savedTitle.isNotEmpty && !savedTitle.startsWith('order_') && !savedTitle.startsWith('call_')) {
          room['orderTitle'] = savedTitle;
        }
        
        // 최근 메시지 가져오기 (병렬)
        futures.add(
          _sb
              .from('chat_messages')
              .select('content, text, createdat')
              .eq('room_id', room['id'])
              .order('createdat', ascending: false)
              .limit(1)
              .maybeSingle()
              .then((last) {
            if (last != null) {
              room['lastMessage'] = (last['content']?.toString() ?? last['text']?.toString() ?? '');
              room['lastMessageAt'] = last['createdat']?.toString();
            } else {
              room['lastMessage'] = '';
            }
          }).catchError((_) {
            room['lastMessage'] = '';
          })
        );
        
        // 읽지 않은 메시지 수 계산 (병렬)
        final isParticipantA = room['participant_a']?.toString() == userId;
        final lastReadAt = isParticipantA 
            ? room['participant_a_last_read_at'] 
            : room['participant_b_last_read_at'];
        
        if (lastReadAt != null) {
          futures.add(
            _sb
                .from('chat_messages')
                .select('id')
                .eq('room_id', room['id'])
                .neq('sender_id', userId)
                .gt('createdat', lastReadAt.toString())
                .then((unreadMessages) {
              room['unreadCount'] = unreadMessages.length;
            }).catchError((_) {
              room['unreadCount'] = 0;
            })
          );
        } else {
          futures.add(
            _sb
                .from('chat_messages')
                .select('id')
                .eq('room_id', room['id'])
                .neq('sender_id', userId)
                .then((unreadMessages) {
              room['unreadCount'] = unreadMessages.length;
            }).catchError((_) {
              room['unreadCount'] = 0;
            })
          );
        }
      }
      
      // 5. 모든 병렬 작업 완료 대기
      await Future.wait(futures);
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;
      debugPrint('✅ [ChatService] 채팅방 목록 로드 완료 (${duration}ms)');
      
      return roomMap.values.toList();
    } catch (e) {
      debugPrint('❌ [ChatService] 채팅방 목록 로드 실패: $e');
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
    await _sb.from('chat_messages').delete().eq('room_id', chatRoomId);
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
      // 사용자 프로필 확인 (users 테이블 사용)
      final customerProfile = await _sb
          .from('users')
          .select('name, businessname')
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