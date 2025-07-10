import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../models/role.dart';
import '../../providers/user_provider.dart';
import '../../widgets/login_required_dialog.dart';
import '../../widgets/common_app_bar.dart';
import '../settings/notification_settings_screen.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final user = userProvider.currentUser;
        
        // 로그인하지 않은 사용자에게 로그인 요구
        if (user == null || user.isAnonymous) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            LoginRequiredDialog.showProfileLoginRequired(context);
          });
          
          return Scaffold(
            appBar: CommonAppBar(
              title: '프로필',
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
            title: '프로필',
            showBackButton: true,
            showHomeButton: true,
          ),
          body: _buildProfileContent(context, user),
        );
      },
    );
  }

  Widget _buildProfileContent(BuildContext context, User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildProfileHeader(user),
          const SizedBox(height: 20),
          _buildProfileActions(context, user),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(User user) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF4F8CFF),
              const Color(0xFF00C6AE),
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _getRoleDisplayName(user.role),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileActions(BuildContext context, User user) {
    return Column(
      children: [
        _buildActionTile(
          context,
          Icons.settings,
          '설정',
          () => context.push('/settings'),
        ),
        _buildActionTile(
          context,
          Icons.notifications,
          '알림 설정',
          () => context.push('/notification-settings'),
        ),
        if (user.role == UserRole.business)
          _buildActionTile(
            context,
            Icons.business,
            '사업자 관리',
            () => context.push('/business/profile'),
          ),
        _buildActionTile(
          context,
          Icons.logout,
          '로그아웃',
          () => _showLogoutDialog(context),
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? const Color(0xFFFF6B6B).withOpacity(0.1)
                      : const Color(0xFF4F8CFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isDestructive
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF4F8CFF),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDestructive
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF222B45),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.business:
        return Colors.orange;
      case UserRole.customer:
        return Colors.blue;
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return '관리자';
      case UserRole.business:
        return '사업자';
      case UserRole.customer:
        return '고객';
    }
  }

  Color _getBusinessStatusColor(BusinessStatus status) {
    switch (status) {
      case BusinessStatus.pending:
        return Colors.orange;
      case BusinessStatus.approved:
        return Colors.green;
      case BusinessStatus.rejected:
        return Colors.red;
    }
  }

  String _getBusinessStatusDisplayName(BusinessStatus status) {
    switch (status) {
      case BusinessStatus.pending:
        return '승인 대기중';
      case BusinessStatus.approved:
        return '승인됨';
      case BusinessStatus.rejected:
        return '승인 거부됨';
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 로그아웃 처리
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
} 