import 'package:allsuriapp/services/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/role.dart';
import '../order/create_order_screen.dart';
import '../order/my_orders_page.dart';
import '../chat/chat_list_page.dart';
import '../profile/profile_screen.dart';
import '../../widgets/admin_dashboard.dart';
import '../../widgets/business_dashboard.dart';
import '../../widgets/customer_dashboard.dart';
import '../customer/create_request_screen.dart';
import '../auth/login_screen.dart';
import '../auth/signup_page.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/login_required_dialog.dart';
import '../settings/notification_settings_screen.dart';
import '../admin/user_management_screen.dart';
import '../business/estimate_requests_screen.dart';
import '../../widgets/common_app_bar.dart';
import '../../utils/responsive_utils.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;
    
    // URL 경로에 따라 역할 결정
    final path = GoRouterState.of(context).uri.path;
    UserRole role;
    
    if (path.startsWith('/admin')) {
      role = UserRole.admin;
    } else if (path.startsWith('/business')) {
      role = UserRole.business;
    } else {
      role = UserRole.customer;
    }

    // 테스트용 사용자가 없으면 생성
    if (currentUser == null) {
      final testUser = User(
        id: 'test_${role.name}_${DateTime.now().millisecondsSinceEpoch}',
        email: 'test_${role.name}@example.com',
        name: '테스트 ${_getRoleDisplayName(role)}',
        role: role,
        phoneNumber: '010-1234-5678',
      );
      
      // 비동기로 사용자 설정
      WidgetsBinding.instance.addPostFrameCallback((_) {
        userProvider.setCurrentUser(testUser);
      });
      
      return Scaffold(
        appBar: CommonAppBar(
          title: '${_getRoleDisplayName(role)} 홈',
          showBackButton: false,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: CommonAppBar(
        title: '${_getRoleDisplayName(role)} 홈',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => context.go('/notifications'),
            tooltip: '알림',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              userProvider.clearCurrentUser();
              context.go('/');
            },
          ),
        ],
      ),
      body: _buildHomeContent(context, currentUser, role),
    );
  }

  Widget _buildHomeContent(BuildContext context, User user, UserRole role) {
    switch (role) {
      case UserRole.admin:
        return _buildAdminHome(context, user);
      case UserRole.business:
        return _buildBusinessHome(context, user);
      case UserRole.customer:
        return _buildCustomerHome(context, user);
    }
  }

  Widget _buildCustomerHome(BuildContext context, User user) {
    return SingleChildScrollView(
      padding: ResponsiveUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserWelcomeCard(user),
          const SizedBox(height: 20),
          Text(
            '서비스 이용',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF222B45),
            ),
          ),
          const SizedBox(height: 12),
          _buildCustomerActions(context, user),
        ],
      ),
    );
  }

  Widget _buildBusinessHome(BuildContext context, User user) {
    return const BusinessDashboard();
  }

  Widget _buildAdminHome(BuildContext context, User user) {
    return const AdminDashboard();
  }

  Widget _buildUserWelcomeCard(User user) {
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '안녕하세요, ${user.name}님!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getRoleDisplayName(user.role),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerActions(BuildContext context, User user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: ResponsiveUtils.getResponsiveGridCrossAxisCount(context),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: ResponsiveUtils.isLandscape(context) ? 2.0 : 1.8,
          children: [
            _buildActionCard(
              context,
              Icons.add,
              '견적 요청',
              () => context.go('/customer/create-request'),
            ),
            _buildActionCard(
              context,
              Icons.history,
              '내 견적',
              () => context.go('/customer/my-estimates'),
            ),
            _buildActionCard(
              context,
              Icons.chat,
              '채팅',
              () => context.go('/chat'),
            ),
            _buildActionCard(
              context,
              Icons.person,
              '프로필',
              () => context.go('/profile'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBusinessActions(BuildContext context, User user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '사업자 서비스',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: ResponsiveUtils.getResponsiveGridCrossAxisCount(context),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: ResponsiveUtils.isLandscape(context) ? 2.0 : 1.8,
          children: [
            _buildActionCard(
              context,
              Icons.list_alt,
              '견적 요청 목록',
              () => context.go('/business/requests'),
            ),
            _buildActionCard(
              context,
              Icons.history,
              '내 견적',
              () => context.go('/business/my-estimates'),
            ),
            _buildActionCard(
              context,
              Icons.chat,
              '채팅',
              () => context.go('/chat'),
            ),
            _buildActionCard(
              context,
              Icons.person,
              '프로필',
              () => context.go('/profile'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '관리자 서비스',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: ResponsiveUtils.getResponsiveGridCrossAxisCount(context),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: ResponsiveUtils.isLandscape(context) ? 2.0 : 1.8,
          children: [
            _buildActionCard(
              context,
              Icons.people,
              '사용자 관리',
              () => context.go('/admin/users'),
            ),
            _buildActionCard(
              context,
              Icons.settings,
              '시스템 설정',
              () => context.go('/settings'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xFFF8F9FB),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F8CFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: const Color(0xFF4F8CFF),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF222B45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
}
