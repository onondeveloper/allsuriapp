import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../models/role.dart';
import '../providers/user_provider.dart';
import 'package:go_router/go_router.dart';

class LoginRequiredDialog extends StatelessWidget {
  final String title;
  final String message;
  final String featureName;

  const LoginRequiredDialog({
    Key? key,
    required this.title,
    required this.message,
    required this.featureName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock, color: Colors.orange[600]),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '로그인 후 이용 가능한 기능',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• 실시간 채팅\n'
                  '• 견적 히스토리\n'
                  '• 푸시 알림\n'
                  '• 개인정보 관리',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            context.push('/');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
          ),
          child: const Text('로그인하기'),
        ),
      ],
    );
  }

  // 편의 메서드들
  static void showChatLoginRequired(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LoginRequiredDialog(
        title: '로그인 필요',
        message: '실시간 채팅 기능을 사용하려면 로그인이 필요합니다.',
        featureName: '채팅',
      ),
    );
  }

  static void showHistoryLoginRequired(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LoginRequiredDialog(
        title: '로그인 필요',
        message: '견적 히스토리를 확인하려면 로그인이 필요합니다.',
        featureName: '히스토리',
      ),
    );
  }

  static void showNotificationLoginRequired(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LoginRequiredDialog(
        title: '로그인 필요',
        message: '푸시 알림을 설정하려면 로그인이 필요합니다.',
        featureName: '알림',
      ),
    );
  }

  static void showProfileLoginRequired(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그인 필요'),
          content: const Text('이 기능을 사용하려면 로그인이 필요합니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _showRoleSelectionDialog(context);
              },
              child: const Text('로그인'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _showRoleSelectionDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('역할 선택'),
          content: const Text('어떤 역할로 로그인하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performGoogleLogin(context, UserRole.customer);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F8CFF),
                foregroundColor: Colors.white,
              ),
              child: const Text('고객'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performGoogleLogin(context, UserRole.business);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C6AE),
                foregroundColor: Colors.white,
              ),
              child: const Text('사업자'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performGoogleLogin(context, UserRole.admin);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                foregroundColor: Colors.white,
              ),
              child: const Text('관리자'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _performGoogleLogin(BuildContext context, UserRole role) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.signInWithGoogle();
      
      if (success && context.mounted) {
        // 로그인 성공 시 사용자 정보 업데이트
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.refreshCurrentUser();
        
        // 역할에 따라 해당 페이지로 이동
        if (context.mounted) {
          switch (role) {
            case UserRole.admin:
              context.go('/admin');
              break;
            case UserRole.business:
              context.go('/business');
              break;
            case UserRole.customer:
              context.go('/customer');
              break;
          }
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google 로그인이 취소되었습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return '관리자';
      case UserRole.business:
        return '사업자';
      case UserRole.customer:
        return '고객';
    }
  }
} 