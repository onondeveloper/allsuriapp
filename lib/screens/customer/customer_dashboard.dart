import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../order/create_order_screen.dart';
import '../customer/my_estimates_screen.dart';
import '../chat/chat_list_page.dart';
import '../profile/profile_screen.dart';
import '../home/home_screen.dart';

class CustomerDashboard extends StatelessWidget {
  const CustomerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('고객 대시보드'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            // 홈 화면으로 이동
            Navigator.pushAndRemoveUntil(
              context,
              CupertinoPageRoute(
                builder: (context) => const HomeScreen(),
              ),
              (route) => false, // 모든 이전 화면 제거
            );
          },
          child: const Text(
            '홈',
            style: TextStyle(
              color: CupertinoColors.systemBlue,
              fontSize: 16,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 섹션
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '환영합니다!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.label,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '사용자: ${user?.name ?? '고객님'}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // 기능 그리드
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildMenuCard(
                      context,
                      '견적 내기',
                      CupertinoIcons.plus_circle,
                      CupertinoColors.systemBlue,
                      () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => const CreateOrderScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      '내 견적',
                      CupertinoIcons.list_bullet,
                      CupertinoColors.systemGreen,
                      () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => const CustomerMyEstimatesScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      '채팅',
                      CupertinoIcons.chat_bubble_2,
                      CupertinoColors.systemOrange,
                      () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => const ChatListPage(),
                          ),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      '프로필',
                      CupertinoIcons.person_circle,
                      CupertinoColors.systemGrey,
                      () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: CupertinoColors.separator,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 