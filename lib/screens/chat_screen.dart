import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/user_provider.dart';
import '../services/media_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';
import '../providers/user_provider.dart';
import '../models/estimate.dart';
import '../models/order.dart';
import '../services/estimate_service.dart';
import '../services/order_service.dart';
import '../services/chat_service.dart';
import '../widgets/common_app_bar.dart';
import './estimate_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String? chatRoomTitle;

  const ChatScreen({
    Key? key,
    required this.chatRoomId,
    this.chatRoomTitle,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToEnd = false;
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSub; // realtime 구독
  String? _otherUserName; // 상대방 이름
  String? _orderTitle; // 오더 제목

  @override
  void initState() {
    super.initState();
    _loadChatRoomInfo(); // 채팅방 정보 로드 (상대방 이름, 오더 제목)
    _loadMessages();
    _subscribeRealtime();
    _scrollController.addListener(() {
      final atBottom = _scrollController.offset <= 100;
      if (_showScrollToEnd == atBottom) {
        setState(() => _showScrollToEnd = !atBottom);
      }
    });
    // 화면 진입 시 입력창에 자동 포커스 -> 키보드 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    });
  }

  Future<void> _loadChatRoomInfo() async {
    try {
      final myId = Provider.of<UserProvider>(context, listen: false).currentUser?.id ?? '';
      
      // 채팅방 정보 가져오기
      final chatRoom = await Supabase.instance.client
          .from('chat_rooms')
          .select('customerid, businessid, participant_a, participant_b, title, listingid')
          .eq('id', widget.chatRoomId)
          .single();
      
      // 상대방 ID 찾기
      String? otherId;
      if (chatRoom['participant_a'] == myId) {
        otherId = chatRoom['participant_b'];
      } else if (chatRoom['participant_b'] == myId) {
        otherId = chatRoom['participant_a'];
      } else if (chatRoom['customerid'] == myId) {
        otherId = chatRoom['businessid'];
      } else if (chatRoom['businessid'] == myId) {
        otherId = chatRoom['customerid'];
      }
      
      // 상대방 이름 가져오기
      if (otherId != null) {
        final user = await Supabase.instance.client
            .from('users')
            .select('businessname, name')
            .eq('id', otherId)
            .single();
        
        setState(() {
          _otherUserName = user['businessname'] ?? user['name'] ?? '사업자';
        });
      }
      
      // 오더 제목 가져오기 (listingid가 있는 경우)
      final listingId = chatRoom['listingid'];
      if (listingId != null) {
        try {
          final listing = await Supabase.instance.client
              .from('marketplace_listings')
              .select('title')
              .eq('id', listingId)
              .single();
          
          setState(() {
            _orderTitle = listing['title'];
          });
        } catch (e) {
          print('⚠️ 오더 제목 조회 실패: $e');
        }
      }
    } catch (e) {
      print('❌ 채팅방 정보 로드 실패: $e');
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final messages = await chatService.getMessages(widget.chatRoomId);
      await chatService.markChatRead(widget.chatRoomId);
      setState(() {
        _messages = messages;
      });
    } catch (e) {
      print('메시지 로드 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _subscribeRealtime() {
    try {
      final client = Supabase.instance.client;
      
      print('🔵 [ChatScreen] Realtime 구독 시작');

      // chat_messages 테이블의 room_id별 스트림 구독 (createdat 기준 정렬)
      _messagesSub = client
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('room_id', widget.chatRoomId)
          .order('createdat', ascending: true)
          .listen((rows) {
        // 현재 사용자 ID를 listen 콜백 내부에서 가져오기
        final me = Provider.of<UserProvider>(context, listen: false).currentUser?.id ?? '';
        
        print('🔔 [ChatScreen] 실시간 메시지 수신: ${rows.length}개, 내 ID: $me');
        
        final mapped = rows.map((r) {
          final m = Map<String, dynamic>.from(r);
          final created = m['createdat'] ?? m['createdAt'] ?? m['created_at'];
          final text = (m['content'] ?? m['text'] ?? '').toString();
          
          // sender_id 확인 (다양한 케이스 대응)
          final senderId = m['sender_id']?.toString() ?? m['senderid']?.toString() ?? m['senderId']?.toString() ?? '';
          
          // 내 아이디와 비교 (공백 제거 및 소문자 변환)
          final isFromMe = senderId.trim().toLowerCase() == me.trim().toLowerCase();
          
          print('   메시지: "$text" (sender: $senderId, me: $me, isFromMe: $isFromMe)');
          
          return <String, dynamic>{
            'text': text,
            'timestamp': DateTime.tryParse(created?.toString() ?? '') ?? DateTime.now(),
            'isFromMe': isFromMe,
          };
        }).toList();
        
        if (!mounted) return;
        setState(() {
          _messages = mapped;
        });

        // 새로운 메시지가 오면 하단으로 스크롤
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!_scrollController.hasClients) return;
          final max = _scrollController.position.maxScrollExtent;
          _scrollController.animateTo(
            max + 60,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        });
      });
    } catch (e) {
      print('❌ 실시간 구독 설정 실패: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final me = Provider.of<UserProvider>(context, listen: false).currentUser?.id ?? '';
      final text = _messageController.text.trim();
      
      print('🔵 [ChatScreen] 메시지 전송 시작');
      print('   보내는 사람 ID: $me');
      print('   메시지: $text');
      
      await chatService.sendMessage(widget.chatRoomId, text, me);
      print('✅ [ChatScreen] 메시지 전송 완료');
      
      _messageController.clear();
      
      // Realtime 구독이 자동으로 업데이트하므로 _loadMessages() 호출 제거
      // (Realtime이 새 메시지를 받아서 UI를 업데이트함)
      
    } catch (e) {
      print('❌ [ChatScreen] 메시지 전송 오류: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_orderTitle ?? widget.chatRoomTitle ?? '채팅'),
            if (_otherUserName != null)
              Text(
                _otherUserName!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              final svc = Provider.of<ChatService>(context, listen: false);
              if (value == 'clear') {
                await svc.deleteMessages(widget.chatRoomId);
                await _loadMessages();
              } else if (value == 'delete') {
                // 소프트 삭제
                final me = Provider.of<UserProvider>(context, listen: false).currentUser?.id ?? '';
                await svc.softDeleteChatRoom(widget.chatRoomId, me);
                if (mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'clear', child: Text('메시지 비우기')),
              const PopupMenuItem(value: 'delete', child: Text('채팅방 삭제')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildChatHeader(),
          Expanded(
            child: Stack(
              children: [
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? const Center(child: Text('아직 메시지가 없습니다.'))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            reverse: false,
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final showDateHeader = _shouldShowDateHeader(index);
                              return Column(
                                children: [
                                  if (showDateHeader) _buildDateHeader(message['timestamp'] as DateTime),
                                  _buildMessageBubble(message),
                                ],
                              );
                            },
                          ),
                if (_showScrollToEnd)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: () {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      },
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ),
              ],
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildChatHeader() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: Provider.of<ChatService>(context, listen: false).getChatRoom(widget.chatRoomId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
        final room = snapshot.data!;
        final estimateId = (room['estimateid']?.toString() ?? '');
        if (estimateId.isEmpty) return const SizedBox.shrink();
        return FutureBuilder<Map<String, dynamic>?>(
          future: _loadEstimateAndOrder(estimateId),
          builder: (context, snap) {
            final info = snap.data;
            if (info == null) return const SizedBox.shrink();
            final order = info['order'] as Order?;
            final title = order?.title ?? '견적';
            return InkWell(
              onTap: order == null ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EstimateDetailScreen(order: order, estimate: info['estimate'] as Estimate),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.grey.shade100,
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _loadEstimateAndOrder(String estimateId) async {
    try {
      final sb = Provider.of<ChatService>(context, listen: false);
      final estSvc = Provider.of<EstimateService>(context, listen: false);
      final ordSvc = Provider.of<OrderService>(context, listen: false);
      // estimate 조회
      final estRows = await estSvc.getEstimates();
      final estimate = estRows.firstWhere((e) => e.id == estimateId, orElse: () => Estimate.empty());
      if (estimate.id.isEmpty) return null;
      final order = await ordSvc.getOrder(estimate.orderId);
      if (order == null) return null;
      return {'estimate': estimate, 'order': order};
    } catch (_) {
      return null;
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isFromMe = message['isFromMe'] as bool;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isFromMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isFromMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[100],
              child: Text(
                (_otherUserName ?? '업체').substring(0, 1),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isFromMe ? Colors.blue[600] : Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['text'],
                    style: TextStyle(
                      color: isFromMe ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(message['timestamp']),
                    style: TextStyle(
                      color: isFromMe ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isFromMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green[100],
              child: Text(
                '나',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _isSending ? null : _pickAndSendImage,
            icon: const Icon(Icons.photo),
            color: Colors.blue[600],
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _inputFocusNode,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '메시지를 입력하세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              enabled: !_isSending,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            color: Colors.blue[600],
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (x == null) return;
      final file = File(x.path);
      final media = MediaService();
      final url = await media.uploadMessageImage(roomId: widget.chatRoomId, userId: Provider.of<UserProvider>(context, listen: false).currentUser?.id ?? '', file: file);
      if (url == null) return;
      // Save as image message
      final nowIso = DateTime.now().toIso8601String();
      final sb = Supabase.instance.client;
      await sb.from('messages').insert({
        'roomid': widget.chatRoomId,
        'senderid': Provider.of<UserProvider>(context, listen: false).currentUser?.id ?? '',
        'type': 'image',
        'image_url': url,
        'createdat': nowIso,
      });
    } catch (e) {
      debugPrint('이미지 전송 실패: $e');
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool _shouldShowDateHeader(int index) {
    if (index == _messages.length - 1) return true; // reversed list
    final current = _messages[index]['timestamp'] as DateTime;
    final next = _messages[index + 1]['timestamp'] as DateTime;
    return !_isSameDay(current, next);
  }

  Widget _buildDateHeader(DateTime date) {
    final label = '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _messageController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }
}
