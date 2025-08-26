import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../business/business_profile_screen.dart';
import 'package:app_settings/app_settings.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.currentUser;
        
        // 로그인하지 않은 사용자에게 안내
        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('프로필'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: _buildLoginGuide(context),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('프로필'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: _buildProfileContent(context, user),
        );
      },
    );
  }

  Widget _buildLoginGuide(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          const Text(
            '프로필을 보려면\n로그인하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '로그인',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4F8CFF),
              Color(0xFF00C6AE),
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
              (user.role == 'business' && (user.businessName != null && user.businessName!.trim().isNotEmpty))
                  ? user.businessName!
                  : user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getRoleDisplayName(user.role),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (user.role == 'business' && (user.businessName == null || user.businessName!.trim().isEmpty)) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '상호명 미입력',
                        style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    )
                  ]
                ],
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
        if (user.role == 'business')
          _buildActionTile(
            context,
            Icons.account_balance_wallet,
            '계정 설정 (결제)',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
              );
            },
          ),
        _buildActionTile(
          context,
          Icons.notifications,
          '알림 설정',
          () {
            AppSettings.openAppSettings();
          },
        ),
        if (user.role == 'business')
          _buildActionTile(
            context,
            Icons.business,
            '사업자 관리',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
              );
            },
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222B45),
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFF222B45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return '관리자';
      case 'business':
        return '사업자';
      case 'customer':
        return '고객';
      default:
        return '사용자';
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Provider.of<AuthService>(context, listen: false).signOut();
              },
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );
  }
} 