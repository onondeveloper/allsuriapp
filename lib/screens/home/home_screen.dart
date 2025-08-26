import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/customer_dashboard.dart';
import '../../widgets/interactive_card.dart';
import '../../widgets/business_dashboard.dart';
import '../business/business_profile_screen.dart';
import '../business/business_pending_screen.dart';
import '../role_selection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // 디버그 로깅 추가
        print('=== HomeScreen Debug ===');
        print('isAuthenticated: ${authService.isAuthenticated}');
        print('currentUser: ${authService.currentUser}');
        print('needsRoleSelection: ${authService.needsRoleSelection}');
        print('========================');
        
        // 역할 선택이 필요한 경우
        if (authService.isAuthenticated && authService.needsRoleSelection) {
          print('역할 선택 화면을 표시합니다!');
          return const RoleSelectionScreen();
        }
        
        // 사업자: 직접 해당 화면 반환 (네비게이션 대신 위젯 교체로 라우팅 혼선 방지)
        if (authService.isAuthenticated && authService.currentUser?.role == 'business') {
          print('사업자 화면을 표시합니다!');
          final u = authService.currentUser!;
          final hasBusinessName = (u.businessName != null && u.businessName!.trim().isNotEmpty);
          final status = (u.businessStatus ?? 'pending').toLowerCase();
          if (!hasBusinessName) {
            return const BusinessProfileScreen();
          }
          if (status != 'approved') {
            return const BusinessPendingScreen();
          }
          return const BusinessDashboard();
        }
        
        return WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('AllSuri'),
            actions: authService.isAuthenticated
                ? [
                    IconButton(
                      tooltip: '로그아웃',
                      onPressed: () => authService.signOut(),
                      icon: const Icon(Icons.logout),
                    ),
                  ]
                : null,
          ),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Modern HERO with gradient + search
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.85),
                        Theme.of(context).colorScheme.secondary.withOpacity(0.85),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.home_repair_service, color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '올수리에 오신 것을 환영합니다',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  authService.isAuthenticated
                                      ? (authService.currentUser?.role == 'business'
                                          ? '${authService.currentUser?.name ?? "사업자"}님, 바로 시작해볼까요?'
                                          : '원하는 서비스를 빠르게 연결해 드려요')
                                      : '전문가와 연결하여 빠르고 안전한 서비스를 받아보세요',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '모든 일감은 여기에~',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const TextField(
                          decoration: InputDecoration(
                            hintText: '어떤 도움이 필요하신가요? (예: 누수, 보일러)',
                            prefixIcon: Icon(Icons.search),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Quick actions (e-com style CTA cards)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: InteractiveCard(
                    onTap: () {
                      if (!(authService.isAuthenticated && authService.currentUser?.role == 'business')) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerDashboard()));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessDashboard()));
                      }
                    },
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.request_quote, color: Theme.of(context).colorScheme.onSecondaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('견적 내기', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('빠른 요청', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),

                const SizedBox(height: 12),

                // Promo carousel style cards
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final colors = [
                        [Colors.blue.shade50, Colors.blue.shade100],
                        [Colors.purple.shade50, Colors.purple.shade100],
                        [Colors.green.shade50, Colors.green.shade100],
                      ];
                      return _PromoCard(gradientColors: colors[index]);
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Move business login CTA to bottom
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: InteractiveCard(
                    onTap: () {
                      if (authService.isAuthenticated) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessDashboard()));
                      } else {
                        _showBusinessLoginDialog(context);
                      }
                    },
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.business, color: Theme.of(context).colorScheme.onSecondaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(authService.isAuthenticated ? '사업자 대시보드' : '사업자 로그인',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('전문가 센터로 이동',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  void _showBusinessLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사업자 로그인'),
        content: const Text('Google 계정으로 로그인하여 사업자 기능을 이용하세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Google 로그인
                await Provider.of<AuthService>(context, listen: false).signInWithGoogle(
                  redirectUrl: 'io.supabase.flutter://login-callback/',
                );
                if (context.mounted) {
                  // 로그인 성공 시 바로 사업자 대시보드로 이동
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BusinessDashboard(),
                    ),
                    (route) => false, // 모든 이전 화면 제거
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  // 로그인 실패 시 에러 메시지 표시
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('로그인에 실패했습니다: ${e.toString()}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Google 로그인'),
          ),
        ],
      ),
    );
  }
}

class _HomeCtaCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _HomeCtaCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final List<Color> gradientColors;
  const _PromoCard({required this.gradientColors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_offer, color: Colors.black87),
              ),
              const SizedBox(width: 12),
              Text('광고', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const Spacer(),
          Text('광고 문의: ', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
