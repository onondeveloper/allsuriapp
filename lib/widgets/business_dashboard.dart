import 'package:allsuriapp/services/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/business/estimate_requests_screen.dart';
import '../screens/business/transfer_estimate_screen.dart';
import '../screens/business/estimate_management_screen.dart';
import '../screens/business/my_estimates_screen.dart';
import '../screens/business/business_profile_screen.dart';
import '../screens/business/transferred_estimates_screen.dart';
import 'package:go_router/go_router.dart';

class BusinessDashboard extends StatelessWidget {
  const BusinessDashboard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final technicianId = authService.currentUser?.id ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSection(
            context,
            '견적 요청 관리',
            [
              _buildActionCard(
                context,
                Icons.list_alt,
                '견적 요청 목록',
                '고객이 올린 견적 요청을 확인하고 견적을 작성합니다',
                () {
                  context.push('/business/estimate-requests');
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            '내 견적 관리',
            [
              _buildActionCard(
                context,
                Icons.assignment,
                '내 견적 목록',
                '제출한 견적을 상태별로 확인합니다',
                () {
                  context.push('/business/my-estimates');
                },
              ),
              _buildActionCard(
                context,
                Icons.swap_horiz,
                '견적 이관 하기',
                '다른 사업자에게 견적을 이관합니다',
                () {
                  context.push('/business/transfer-estimate');
                },
              ),
              _buildActionCard(
                context,
                Icons.transfer_within_a_station,
                '이관한 견적',
                '다른 사업자에게 이관한 견적을 확인합니다',
                () {
                  context.push('/business/transferred-estimates');
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            '프로필 관리',
            [
              _buildActionCard(
                context,
                Icons.person,
                '프로필 편집',
                '사업자 정보, 활동 지역, 전문 분야를 설정합니다',
                () {
                  context.push('/business/profile');
                },
              ),

            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '사업자 가이드',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• 견적 요청 목록: 고객이 올린 견적 요청을 확인하고 견적을 작성할 수 있습니다.\n'
                  '• 이관한 견적: 다른 사업자에게 이관한 견적을 확인할 수 있습니다.\n'
                  '• 프로필 편집: 활동 지역과 전문 분야를 설정할 수 있습니다.',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, List<Widget> children) {
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
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 160, // 고정 높이 설정
          padding: const EdgeInsets.all(20.0),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C6AE).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: const Color(0xFF00C6AE),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF222B45),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
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
}
