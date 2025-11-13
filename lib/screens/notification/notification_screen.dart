import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/common_app_bar.dart';
import '../business/job_management_screen.dart';
import '../business/order_marketplace_screen.dart';
import '../business/order_bidders_screen.dart';
import '../community/post_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;
      
      print('🔍 [NotificationScreen] 알림 로드 시작');
      print('   UserProvider currentUser: ${user?.id ?? "null"}');
      
      if (user != null) {
        print('   사용자 ID로 알림 조회: ${user.id}');
        final notifications = await _notificationService.getNotifications(user.id);
        print('✅ [NotificationScreen] ${notifications.length}개 알림 조회 완료');
        
        if (notifications.isNotEmpty) {
          print('   첫 번째 알림: ${notifications.first}');
        }
        
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      } else {
        print('❌ [NotificationScreen] UserProvider에 사용자 없음');
        setState(() {
          _error = '사용자 정보를 찾을 수 없습니다.';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ [NotificationScreen] 알림 로드 실패: $e');
      setState(() {
        _error = '알림을 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    // 1. 읽음 처리
    if (notification['isread'] != true) {
      await _notificationService.markAsRead(notification['id']);
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == notification['id']);
        if (index != -1) {
          _notifications[index]['isread'] = true;
        }
      });
    }
    
    // 2. 알림 타입에 따라 페이지 이동
    final type = notification['type'] as String?;
    
    if (type == 'bid_pending') {
      // 입찰 확인 - 오더 마켓플레이스로 이동
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OrderMarketplaceScreen(),
        ),
      );
    } else if (type == 'new_bid') {
      // 새로운 입찰 - 입찰자 목록으로 이동
      final listingId = (notification['jobid'] ?? notification['jobId'])?.toString();
      if (listingId != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderBiddersScreen(listingId: listingId),
          ),
        );
      }
    }
    // 다른 타입들도 필요시 추가
  }

  Future<void> _markAllAsRead() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;
    
    if (user != null) {
      await _notificationService.markAllAsRead(user.id);
      setState(() {
        _notifications = _notifications.map((n) => {...n, 'isread': true}).toList();
      });
    }
  }

  String _formatTimeAgo(dynamic dateTimeValue) {
    DateTime dateTime;
    
    // String인 경우 파싱, 이미 DateTime인 경우 그대로 사용
    if (dateTimeValue is String) {
      try {
        dateTime = DateTime.parse(dateTimeValue);
      } catch (e) {
        return '시간 정보 없음';
      }
    } else if (dateTimeValue is DateTime) {
      dateTime = dateTimeValue;
    } else {
      return '시간 정보 없음';
    }
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

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

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'comment':
        return Icons.comment;
      case 'new_bid':
        return Icons.gavel;
      case 'bid_pending':
        return Icons.schedule;
      case 'bid_selected':
        return Icons.check_circle;
      case 'bid_rejected':
        return Icons.cancel;
      case 'estimate':
        return Icons.assignment;
      case 'estimate_selected':
        return Icons.emoji_events;
      case 'estimate_transferred':
        return Icons.swap_horiz;
      case 'order_completed':
        return Icons.done_all;
      case 'review_received':
        return Icons.star;
      case 'order_status':
        return Icons.update;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'comment':
        return Colors.purple;
      case 'new_bid':
        return Colors.orange;
      case 'bid_pending':
        return Colors.blue;
      case 'bid_selected':
        return Colors.green;
      case 'bid_rejected':
        return Colors.grey;
      case 'estimate':
        return Colors.blue;
      case 'estimate_selected':
        return Colors.green;
      case 'estimate_transferred':
        return Colors.teal;
      case 'order_completed':
        return Colors.green;
      case 'review_received':
        return Colors.amber;
      case 'order_status':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '알림',
        showBackButton: true,
        showHomeButton: true,
        actions: [
          if (_notifications.any((n) => n['isread'] != true))
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _markAllAsRead,
              tooltip: '모두 읽음 처리',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            '알림이 없습니다.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return _buildNotificationItem(notification);
                        },
                      ),
                    ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    // null 안전성을 위한 기본값 설정
    final title = notification['title']?.toString() ?? '제목 없음';
    final message = notification['body']?.toString() ?? notification['message']?.toString() ?? '내용 없음';
    final type = notification['type']?.toString() ?? 'unknown';
    final isRead = notification['isread'] == true;
    final jobTitle = notification['jobtitle']?.toString();
    final region = notification['region']?.toString();
    final createdAt = notification['createdat'];
    final jobId = notification['jobid']?.toString();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isRead ? Colors.white : Colors.blue[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getNotificationColor(type).withOpacity(0.1),
          child: Icon(
            _getNotificationIcon(type),
            color: _getNotificationColor(type),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if ((jobTitle?.isNotEmpty ?? false) || (region?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 4),
              Text(
                '${jobTitle ?? ''}${(jobTitle?.isNotEmpty ?? false) && (region?.isNotEmpty ?? false) ? ' · ' : ''}${region ?? ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _formatTimeAgo(createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await _markAsRead(notification);
                  if (!mounted) return;
                  
                  // 알림 타입에 따라 다른 화면으로 이동
                  if (type == 'comment') {
                    // 댓글 알림 → 게시글 상세 화면
                    final postId = notification['postid']?.toString() ?? '';
                    if (postId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(postId: postId),
                        ),
                      );
                    }
                  } else if (type == 'new_bid') {
                    // 새로운 입찰 → 입찰자 목록 화면
                    final listingId = notification['jobid']?.toString() ?? notification['jobId']?.toString() ?? '';
                    final orderTitle = notification['title']?.toString() ?? '오더';
                    if (listingId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderBiddersScreen(
                            listingId: listingId,
                            orderTitle: orderTitle,
                          ),
                        ),
                      );
                    }
                  } else if (type == 'bid_selected') {
                    // 입찰 선택됨 → 내 공사 화면
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JobManagementScreen()),
                    );
                  } else if (type == 'bid_rejected') {
                    // 입찰 거절됨 → 오더 마켓
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OrderMarketplaceScreen()),
                    );
                  } else if (type == 'order_completed' || type == 'review_received') {
                    // 공사 완료 / 리뷰 받음 → 내 공사
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JobManagementScreen()),
                    );
                  } else if ((type == 'call_assigned' || type == 'call_update') && (jobId?.isNotEmpty ?? false)) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OrderMarketplaceScreen()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JobManagementScreen()),
                    );
                  }
                },
                child: const Text('자세히 보기'),
              ),
            )
          ],
        ),
        trailing: isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () => _markAsRead(notification),
      ),
    );
  }
} 