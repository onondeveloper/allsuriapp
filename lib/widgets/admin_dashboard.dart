import 'package:flutter/material.dart';
import '../screens/admin/user_management_screen.dart';
import '../screens/admin/business_approval_screen.dart';
import '../screens/admin/estimate_management_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSection(
            context,
            '회원 관리',
            [
              _buildActionCard(
                context,
                '사용자 관리',
                '전체 사용자 목록을 확인하고 관리합니다',
                Icons.people,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserManagementScreen(),
                    ),
                  );
                },
              ),
              _buildActionCard(
                context,
                '사업자 승인',
                '사업자 등록 요청을 검토하고 승인합니다',
                Icons.business_center,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BusinessApprovalScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            '견적 관리',
            [
              _buildActionCard(
                context,
                '견적 현황',
                '전체 견적 현황을 확인하고 관리합니다',
                Icons.assessment,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EstimateManagementScreen(),
                    ),
                  );
                },
              ),
              _buildActionCard(
                context,
                '견적 처리',
                '견적 요청을 검토하고 처리합니다',
                Icons.edit_document,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EstimateManagementScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            '시스템 관리',
            [
              _buildActionCard(
                context,
                '시스템 설정',
                '시스템 설정을 관리합니다',
                Icons.settings,
                () {
                  // TODO: Implement system settings screen
                },
              ),
              _buildActionCard(
                context,
                '통계 및 보고서',
                '시스템 사용 통계와 보고서를 확인합니다',
                Icons.analytics,
                () {
                  // TODO: Implement analytics screen
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