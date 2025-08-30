import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/common_app_bar.dart';
import '../business/job_management_screen.dart';
import '../business/call_marketplace_screen.dart';

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
      
      if (user != null) {
        final notifications = await _notificationService.getNotifications(user.id);
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '사용자 정보를 찾을 수 없습니다.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '알림을 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    if (notification['isread'] != true) {
      await _notificationService.markAsRead(notification['id']);
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == notification['id']);
        if (index != -1) {
          _notifications[index]['isread'] = true;
        }
      });
    }
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
      case 'estimate':
        return Icons.assignment;
      case 'estimate_selected':
        return Icons.emoji_events;
      case 'order_status':
        return Icons.update;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'estimate':
        return Colors.blue;
      case 'estimate_selected':
        return Colors.green;
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
                  if ((type == 'call_assigned' || type == 'call_update') && (jobId?.isNotEmpty ?? false)) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CallMarketplaceScreen()));
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const JobManagementScreen()));
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