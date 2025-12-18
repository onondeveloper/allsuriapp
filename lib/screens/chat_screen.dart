import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/user.dart';
import '../services/media_service.dart';
import '../models/estimate.dart';
import '../models/order.dart';
import '../services/estimate_service.dart';
import '../services/order_service.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../widgets/common_app_bar.dart';
import './estimate_detail_screen.dart';
import 'business/job_management_screen.dart';
import 'business/my_order_management_screen.dart';

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
  String? _listingId; // 오더 ID (marketplace_listings id)

  @override
  void initState() {
    super.initState();
    _loadChatRoomInfo(); // 채팅방 정보 로드 (상대방 이름, 오더 제목)
    _loadMessages();
    _subscribeRealtime();
    _markAsRead(); // 채팅방 읽음 처리
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

  /// 채팅방을 읽음 처리
  Future<void> _markAsRead() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final chatService = Provider.of<ChatService>(context, listen: false);
      final currentUserId = authService.currentUser?.id ?? '';
      
      if (currentUserId.isNotEmpty) {
        await chatService.markChatRead(widget.chatRoomId, currentUserId);
      }
    } catch (e) {
      print('❌ 읽음 처리 실패: $e');
    }
  }

  Future<void> _loadChatRoomInfo() async {
    try {
      final myId = Provider.of<AuthService>(context, listen: false).currentUser?.id ?? '';
      
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
            _listingId = listingId; // listingId 저장
          });
        } catch (e) {
          print('⚠️ 오더 제목 조회 실패: $e');
        }
      }
    } catch (e) {
      print('❌ 채팅방 정보 로드 실패: $e');
    }
  }

  Future<void> _navigateToOrder() async {
    if (_listingId == null) return;
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id ?? '';
      
      print('🔍 [_navigateToOrder] 오더로 이동 시작');
      print('   Listing ID: $_listingId');
      print('   현재 사용자 ID: $currentUserId');
      
      // 1. marketplace_listings 조회 (jobid 포함)
      final listing = await Supabase.instance.client
          .from('marketplace_listings')
          .select('posted_by, status, jobid')
          .eq('id', _listingId!)
          .single();
      
      final postedBy = listing['posted_by'];
      final jobId = listing['jobid'];
      print('   Posted By: $postedBy');
      print('   Job ID: $jobId');
      
      // 2. 내가 발주자인지 확인
      if (postedBy == currentUserId) {
        // 내가 발주자 -> 내 오더 관리로 이동 (listingId 하이라이트)
        print('   → 내 오더 관리로 이동 (listingId: $_listingId)');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MyOrderManagementScreen(highlightedOrderId: _listingId),
          ),
        );
      } else {
        // 내가 낙찰받은 사업자 -> 내 공사 관리로 이동 (jobId 하이라이트)
        print('   → 내 공사 관리로 이동 (jobId: $jobId)');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => JobManagementScreen(highlightedJobId: jobId),
          ),
        );
      }
    } catch (e) {
      print('❌ [_navigateToOrder] 오더 이동 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오더 정보를 불러올 수 없습니다.')),
        );
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id ?? '';
      
      print('🔍 [_loadMessages] 메시지 로드 시작');
      print('   현재 사용자 ID: $currentUserId');
      
      // chat_messages 직접 조회 (ChatService 대신)
      final client = Supabase.instance.client;
      final rows = await client
          .from('chat_messages')
          .select()
          .eq('room_id', widget.chatRoomId)
          .order('createdat', ascending: true);
      
      final messages = rows.map((r) {
        final m = Map<String, dynamic>.from(r);
        final created = m['createdat'] ?? m['createdAt'] ?? m['created_at'];
        final senderId = m['sender_id']?.toString() ?? '';
        final isFromMe = senderId == currentUserId;
        
        return <String, dynamic>{
          'text': (m['content'] ?? m['text'] ?? '').toString(),
          'timestamp': DateTime.tryParse(created?.toString() ?? '') ?? DateTime.now(),
          'isFromMe': isFromMe,
          'sender_id': senderId,
          'image_url': m['image_url'],
          'video_url': m['video_url'],
        };
      }).toList();
      
      print('   로드된 메시지: ${messages.length}개');
      for (var msg in messages) {
        print('   - sender_id: ${msg['sender_id']}, isFromMe: ${msg['isFromMe']}, text: ${msg['text']}');
      }
      
      setState(() {
        _messages = messages;
      });
    } catch (e) {
      print('❌ [_loadMessages] 메시지 로드 오류: $e');
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
        final me = Provider.of<AuthService>(context, listen: false).currentUser?.id ?? '';
        
        print('🔔 [_subscribeRealtime] 실시간 메시지 수신: ${rows.length}개');
        print('   현재 사용자 ID: "$me" (길이: ${me.length})');
        
        final mapped = rows.map((r) {
          final m = Map<String, dynamic>.from(r);
          final created = m['createdat'] ?? m['createdAt'] ?? m['created_at'];
          final text = (m['content'] ?? m['text'] ?? '').toString();
          
          // sender_id 확인 (다양한 케이스 대응)
          final senderId = m['sender_id']?.toString() ?? m['senderid']?.toString() ?? m['senderId']?.toString() ?? '';
          
          print('   메시지: "$text"');
          print('      sender_id: "$senderId" (길이: ${senderId.length})');
          print('      me: "$me" (길이: ${me.length})');
          print('      같은가? ${senderId == me}');
          
          // 내 아이디와 비교
          final isFromMe = senderId == me;
          
          print('      isFromMe: $isFromMe');
          
          return <String, dynamic>{
            'text': text,
            'timestamp': DateTime.tryParse(created?.toString() ?? '') ?? DateTime.now(),
            'isFromMe': isFromMe,
            'sender_id': senderId, // 디버깅용
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
      final authService = Provider.of<AuthService>(context, listen: false);
      final me = authService.currentUser?.id ?? '';
      final text = _messageController.text.trim();
      
      print('🔵 [_sendMessage] 메시지 전송 시작');
      print('   보내는 사람 ID: "$me" (길이: ${me.length})');
      print('   메시지: "$text"');
      
      await chatService.sendMessage(widget.chatRoomId, text, me);
      print('✅ [_sendMessage] 메시지 전송 완료');
      
      _messageController.clear();
      
      // 메시지 전송 후 즉시 화면 업데이트
      await _loadMessages();
      
      // 하단으로 스크롤
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
      
    } catch (e) {
      print('❌ [ChatScreen] 메시지 전송 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메시지 전송 실패: ${e.toString()}')),
        );
      }
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
        title: InkWell(
          onTap: _listingId != null ? () => _navigateToOrder() : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _orderTitle ?? widget.chatRoomTitle ?? '채팅',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_listingId != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, size: 12),
                  ],
                ],
              ),
              if (_otherUserName != null)
                Text(
                  _otherUserName!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
            ],
          ),
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
                final me = Provider.of<AuthService>(context, listen: false).currentUser?.id ?? '';
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
                  // 이미지가 있으면 이미지 표시
                  if (message['image_url'] != null && message['image_url'].toString().isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () {
                          // 이미지 풀스크린 보기
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.black,
                              child: Stack(
                                children: [
                                  InteractiveViewer(
                                    child: Image.network(
                                      message['image_url'],
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Center(
                                          child: Icon(Icons.error, color: Colors.red, size: 48),
                                        );
                                      },
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 250,
                            maxHeight: 300,
                          ),
                          child: Image.network(
                            message['image_url'],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 250,
                                height: 200,
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 250,
                                height: 200,
                                color: Colors.grey[300],
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('이미지를 불러올 수 없습니다', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // 동영상이 있으면 동영상 표시
                  if (message['video_url'] != null && message['video_url'].toString().isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: VideoPlayerWidget(
                        videoUrl: message['video_url'],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // 텍스트 (이미지/동영상만 있는 경우 텍스트는 숨김)
                  if (message['text'].toString().isNotEmpty && 
                      message['text'] != '[이미지]' && 
                      message['text'] != '[동영상]')
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
            tooltip: '이미지 보내기',
          ),
          IconButton(
            onPressed: _isSending ? null : _pickAndSendVideo,
            icon: const Icon(Icons.videocam),
            color: Colors.blue[600],
            tooltip: '동영상 보내기',
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
      
      // 로딩 표시
      if (mounted) {
        setState(() => _isSending = true);
      }
      
      final file = File(x.path);
      final media = MediaService();
      final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.id ?? '';
      
      print('🔵 [ChatScreen] 이미지 전송 시작');
      
      final url = await media.uploadMessageImage(
        roomId: widget.chatRoomId, 
        userId: currentUserId, 
        file: file,
      );
      
      if (url == null) {
        throw Exception('이미지 업로드 실패');
      }
      
      // Save as image message
      final nowIso = DateTime.now().toIso8601String();
      final sb = Supabase.instance.client;
      await sb.from('chat_messages').insert({
        'room_id': widget.chatRoomId,
        'sender_id': currentUserId,
        'content': '[이미지]',
        'image_url': url,
        'createdat': nowIso,
      });
      
      print('✅ [ChatScreen] 이미지 전송 완료');
      
      // 메시지 목록 새로고침
      await _loadMessages();
      
      // 하단으로 스크롤
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
      
    } catch (e) {
      print('❌ [ChatScreen] 이미지 전송 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 전송 실패: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  /// 동영상 선택 및 전송
  Future<void> _pickAndSendVideo() async {
    try {
      final media = MediaService();
      final videoFile = await media.pickVideoFromGallery();
      if (videoFile == null) return;
      
      // 로딩 표시
      if (mounted) {
        setState(() => _isSending = true);
      }
      
      final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.id ?? '';
      
      print('🎬 [ChatScreen] 동영상 전송 시작');
      
      final url = await media.uploadMessageVideo(
        roomId: widget.chatRoomId, 
        userId: currentUserId, 
        file: videoFile,
      );
      
      if (url == null) {
        throw Exception('동영상 업로드 실패');
      }
      
      // Save as video message
      final nowIso = DateTime.now().toIso8601String();
      final sb = Supabase.instance.client;
      await sb.from('chat_messages').insert({
        'room_id': widget.chatRoomId,
        'sender_id': currentUserId,
        'content': '[동영상]',
        'video_url': url,
        'createdat': nowIso,
      });
      
      print('✅ [ChatScreen] 동영상 전송 완료');
      
      // 메시지 목록 새로고침
      await _loadMessages();
      
      // 하단으로 스크롤
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
      
    } catch (e) {
      print('❌ [ChatScreen] 동영상 전송 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('동영상 전송 실패: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
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

/// 동영상 플레이어 위젯
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('❌ 동영상 초기화 실패: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        width: 250,
        height: 200,
        color: Colors.grey[300],
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('동영상을 불러올 수 없습니다', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        width: 250,
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_controller.value.isPlaying) {
            _controller.pause();
          } else {
            _controller.play();
          }
        });
      },
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 250,
          maxHeight: 300,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
            // 재생/일시정지 아이콘
            if (!_controller.value.isPlaying)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            // 진행 표시줄
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.blue,
                  backgroundColor: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
