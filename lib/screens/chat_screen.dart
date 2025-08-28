import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToEnd = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
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

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final me = Provider.of<UserProvider>(context, listen: false).currentUser?.id ?? '';
      final text = _messageController.text.trim();
      await chatService.sendMessage(widget.chatRoomId, text, me);
      _messageController.clear();
      // 낙관적 UI 업데이트
      setState(() {
        _messages.add({
          'text': text,
          'timestamp': DateTime.now(),
          'isFromMe': true,
        });
      });
      // 스크롤 하단으로 이동
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('메시지 전송 오류: $e');
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
      appBar: CommonAppBar(
        title: widget.chatRoomTitle ?? '채팅',
        showBackButton: true,
        showHomeButton: false,
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
                '업체',
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
    _messageController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }
}
