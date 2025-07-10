import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../widgets/login_required_dialog.dart';
import '../../widgets/common_app_bar.dart';
import '../chat_screen.dart';
import 'package:go_router/go_router.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final user = userProvider.currentUser;
        
        // 로그인하지 않은 사용자에게 로그인 요구
        if (user == null || user.isAnonymous) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            LoginRequiredDialog.showChatLoginRequired(context);
          });
          
          return Scaffold(
            appBar: CommonAppBar(
              title: '채팅',
              showBackButton: true,
              showHomeButton: true,
            ),
            body: const Center(
              child: Text('로그인이 필요한 기능입니다.'),
            ),
          );
        }

        return Scaffold(
          appBar: CommonAppBar(
            title: '채팅',
            showBackButton: true,
            showHomeButton: true,
          ),
          body: _buildChatList(context, user),
        );
      },
    );
  }

  Widget _buildChatList(BuildContext context, User user) {
    // 임시 채팅 목록 데이터
    final chatRooms = [
      {
        'id': '1',
        'title': '에어컨 수리 견적',
        'lastMessage': '견적서를 보내드렸습니다.',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
        'unreadCount': 1,
      },
      {
        'id': '2',
        'title': '배관 수리 견적',
        'lastMessage': '언제 방문 가능하신가요?',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'unreadCount': 0,
      },
      {
        'id': '3',
        'title': '전기공사 견적',
        'lastMessage': '감사합니다.',
        'timestamp': DateTime.now().subtract(const Duration(days: 1)),
        'unreadCount': 0,
      },
    ];

    if (chatRooms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '아직 채팅방이 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '견적 요청을 하면 업체와 채팅할 수 있습니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: chatRooms.length,
      itemBuilder: (context, index) {
        final chatRoom = chatRooms[index];
        return _buildChatItem(context, chatRoom);
      },
    );
  }

  Widget _buildChatItem(BuildContext context, Map<String, dynamic> chatRoom) {
    return Card(
      child: InkWell(
        onTap: () => context.push('/chat'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F8CFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: const Color(0xFF4F8CFF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chatRoom['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF222B45),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chatRoom['lastMessage'] ?? '메시지가 없습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(chatRoom['timestamp']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (chatRoom['unreadCount'] > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        chatRoom['unreadCount'].toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
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
} 