import 'package:flutter/material.dart';
import '../screens/create_estimate_screen.dart';
import '../screens/business/estimate_requests_screen.dart';
import '../screens/business/transfer_estimate_screen.dart';
import '../screens/business/estimate_management_screen.dart';
import '../services/auth_service.dart';
import '../models/order.dart';

class BusinessDashboard extends StatelessWidget {
  final AuthService authService;
  final String technicianId;

  const BusinessDashboard({
    Key? key,
    required this.authService,
    required this.technicianId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSection(
            context,
            '견적 관리',
            [
              _buildActionCard(
                context,
                '견적 요청 목록',
                '고객의 견적 요청을 확인합니다',
                Icons.list_alt,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EstimateRequestsScreen(),
                    ),
                  );
                },
              ),
              _buildActionCard(
                context,
                '견적 이관',
                '다른 사업자에게 견적을 이관합니다',
                Icons.swap_horiz,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransferEstimateScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            '내 견적',
            [
              _buildActionCard(
                context,
                '내 견적 관리',
                '제출한 견적을 수정/삭제하고 관리합니다',
                Icons.manage_accounts,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EstimateManagementScreen(
                        authService: authService,
                        technicianId: technicianId,
                      ),
                    ),
                  );
                },
              ),
              _buildActionCard(
                context,
                '진행중인 견적',
                '현재 진행 중인 견적을 관리합니다',
                Icons.pending_actions,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EstimateManagementScreen(
                        authService: authService,
                        technicianId: technicianId,
                      ),
                    ),
                  );
                },
              ),
              _buildActionCard(
                context,
                '완료된 견적',
                '완료된 견적 내역을 확인합니다',
                Icons.done_all,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EstimateManagementScreen(
                        authService: authService,
                        technicianId: technicianId,
                      ),
                    ),
                  );
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