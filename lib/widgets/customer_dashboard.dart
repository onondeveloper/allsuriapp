import 'package:flutter/material.dart';
import '../screens/customer/create_request_screen.dart';
import '../screens/customer/request_list_screen.dart';

class CustomerDashboard extends StatelessWidget {
  const CustomerDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSection(
            context,
            '견적 요청',
            [
              _buildActionCard(
                context,
                '새 견적 요청',
                '새로운 수리 견적을 요청합니다',
                Icons.add_circle,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateRequestScreen(),
                    ),
                  );
                },
              ),
              _buildActionCard(
                context,
                '견적 요청 목록',
                '내가 요청한 견적 목록을 확인합니다',
                Icons.list_alt,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RequestListScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            '진행중인 수리',
            [
              _buildActionCard(
                context,
                '작업 현황',
                '진행중인 수리 작업의 현황을 확인합니다',
                Icons.build,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RequestListScreen(),
                    ),
                  );
                },
              ),
              _buildActionCard(
                context,
                '완료된 수리',
                '완료된 수리 내역을 확인합니다',
                Icons.done_all,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RequestListScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            '내 정보',
            [
              _buildActionCard(
                context,
                '프로필 관리',
                '내 프로필 정보를 관리합니다',
                Icons.person,
                () {
                  // TODO: Implement profile management screen
                },
              ),
              _buildActionCard(
                context,
                '알림 설정',
                '알림 설정을 관리합니다',
                Icons.notifications,
                () {
                  // TODO: Implement notification settings screen
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: children,
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Theme.of(context).primaryColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 