import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/business/estimate_requests_screen.dart';
import '../screens/business/my_estimates_screen.dart';
import '../screens/business/create_job_screen.dart';
import '../screens/business/transfer_estimate_screen.dart';
import '../screens/notification/notification_screen.dart';
import '../screens/business/job_management_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../screens/home/home_screen.dart';
import '../widgets/bottom_navigation.dart';
import 'interactive_card.dart';

class BusinessDashboard extends StatefulWidget {
  const BusinessDashboard({Key? key}) : super(key: key);

  @override
  State<BusinessDashboard> createState() => _BusinessDashboardState();
}

class _BusinessDashboardState extends State<BusinessDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.currentUser;
        final businessName = (user?.businessName != null && user!.businessName!.trim().isNotEmpty)
            ? user.businessName!
            : (user?.name ?? "사업자");
        
        return Scaffold(
          appBar: AppBar(
            title: Text('$businessName with 올수리'),
            centerTitle: true,
            actions: [
              FutureBuilder<int>(
                future: NotificationService().getUnreadCount(user?.id ?? ''),
                builder: (context, snapshot) {
                  final unread = snapshot.data ?? 0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationScreen()),
                          );
                        },
                        tooltip: '알림',
                      ),
                      if (unread > 0)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              unread.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modern welcome banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.12),
                        Theme.of(context).colorScheme.secondary.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.business, size: 28, color: Theme.of(context).colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$businessName 님, 오늘도 안전한 서비스 제공을 응원합니다!',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Menu grid (card-based)
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildMenuCard(
                      context,
                      '견적 확인하기',
                      Icons.search,
                      Colors.blue,
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const EstimateRequestsScreen()));
                      },
                    ),
                    _buildMenuCard(
                      context,
                      '내 견적 목록',
                      Icons.list_alt,
                      Colors.green,
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const BusinessMyEstimatesScreen()));
                      },
                    ),
                    _buildMenuCard(
                      context,
                      '공사 만들기',
                      Icons.construction,
                      Colors.orange,
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateJobScreen()));
                      },
                    ),
                    _buildMenuCard(
                      context,
                      '공사 관리',
                      Icons.assignment_turned_in,
                      Colors.teal,
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const JobManagementScreen()));
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigation(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InteractiveCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
