import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/home/home_screen.dart';
import '../screens/customer/my_estimates_screen.dart';
import '../screens/business/estimate_management_screen.dart';
import '../screens/business/create_job_screen.dart';
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
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              height: 62,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    context: context,
                    index: 0,
                    icon: Icons.home_rounded,
                    outlinedIcon: Icons.home_outlined,
                    label: '홈',
                    isCustomer: isCustomer,
                  ),
                  _buildNavItem(
                    context: context,
                    index: 1,
                    icon: Icons.construction_rounded,
                    outlinedIcon: Icons.construction_outlined,
                    label: isCustomer ? '내 견적' : '공사 만들기',
                    isCustomer: isCustomer,
                  ),
                  _buildNavItem(
                    context: context,
                    index: 2,
                    icon: Icons.chat_bubble_rounded,
                    outlinedIcon: Icons.chat_bubble_outline_rounded,
                    label: '채팅',
                    isCustomer: isCustomer,
                  ),
                  _buildNavItem(
                    context: context,
                    index: 3,
                    icon: Icons.account_circle_rounded,
                    outlinedIcon: Icons.account_circle_outlined,
                    label: '프로필',
                    isCustomer: isCustomer,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required IconData outlinedIcon,
    required String label,
    required bool isCustomer,
  }) {
    final isSelected = currentIndex == index;
    final primaryColor = Theme.of(context).primaryColor;
    
    return Expanded(
      child: InkWell(
        onTap: () {
          switch (index) {
            case 0:
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      isCustomer ? const CustomerDashboard() : const BusinessDashboard(),
                ),
                (route) => false,
              );
              break;
            case 1:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => isCustomer
                      ? const CustomerMyEstimatesScreen()
                      : const CreateJobScreen(),
                ),
              );
              break;
            case 2:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatListPage(),
                ),
              );
              break;
            case 3:
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
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(isSelected ? 6 : 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSelected ? icon : outlinedIcon,
                  size: isSelected ? 24 : 22,
                  color: isSelected ? primaryColor : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? primaryColor : Colors.grey[700],
                  letterSpacing: -0.3,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 