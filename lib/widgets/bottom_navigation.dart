import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/home/home_screen.dart';
import '../screens/customer/my_estimates_screen.dart';
import '../screens/business/estimate_management_screen.dart';
import '../screens/chat/chat_list_page.dart';
import '../screens/profile/profile_screen.dart';
import '../widgets/customer_dashboard.dart';
import '../widgets/business_dashboard.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final isCustomer = authService.currentUser?.role != 'business';
        
        return BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: currentIndex,
          onTap: (index) {
            switch (index) {
              case 0: // 홈
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => isCustomer 
                        ? const CustomerDashboard() 
                        : const BusinessDashboard(),
                  ),
                  (route) => false,
                );
                break;
              case 1: // 내 견적
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => isCustomer 
                        ? const CustomerMyEstimatesScreen()
                        : const EstimateManagementScreen(),
                  ),
                );
                break;
              case 2: // 채팅
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatListPage(),
                  ),
                );
                break;
              case 3: // 프로필
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
                break;
            }
            onTap(index);
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.assignment),
              label: isCustomer ? '내 견적' : '견적 관리',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.chat),
              label: '채팅',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: '프로필',
            ),
          ],
        );
      },
    );
  }
} 