import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../../widgets/customer_dashboard.dart';
import '../../widgets/interactive_card.dart';
import '../../widgets/business_dashboard.dart';
import '../business/business_profile_screen.dart';
import '../business/business_pending_screen.dart';
import '../role_selection_screen.dart';
import '../../models/order.dart' as app_models;
import '../customer/create_request_screen.dart';
import '../customer/my_estimates_screen.dart';

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
                // Modern HERO with gradient
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
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
                          const SizedBox(width: 14),
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
                                const SizedBox(height: 4),
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
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 내 견적 바로가기 (과거 제출 이력 있는 경우만)
                      FutureBuilder<int>(
                        future: _fetchMyOrderCount(context),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          if (count <= 0) return const SizedBox.shrink();
                          return SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white70),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CustomerMyEstimatesScreen()),
                                );
                              },
                              icon: const Icon(Icons.assignment_turned_in_outlined, color: Colors.white),
                              label: const Text('내 견적 바로가기'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 카테고리 칩 / 그리드 (아이콘 커스터마이즈)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final isTablet = width >= 600;
                      final crossAxisCount = isTablet ? 6 : 3; // 약 30% 축소: 폰 3열, 태블릿 6열
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: app_models.Order.CATEGORIES.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.0, // 정사각형
                        ),
                        itemBuilder: (context, index) {
                          final c = app_models.Order.CATEGORIES[index];
                          final color = _categoryColor(context, c);
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CreateRequestScreen(initialCategory: c),
                                  ),
                                );
                              },
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(_categoryIcon(c), size: 36, color: color),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      c,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // 사용자 리뷰/광고 예정 영역 (중간 비우기용 플레이스홀더)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Center(
                      child: Text(
                        '사용자 리뷰 · 광고 영역 (준비중)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
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

  static IconData _categoryIcon(String category) {
    switch (category) {
      case '누수':
        return Icons.water_damage_outlined;
      case '화장실':
        return Icons.wc;
      case '배관':
        return Icons.plumbing;
      case '난방':
        return Icons.device_thermostat;
      case '주방':
        return Icons.kitchen_outlined;
      case '리모델링':
        return Icons.handyman_outlined;
      default:
        return Icons.build_circle_outlined;
    }
  }

  static Color _categoryColor(BuildContext context, String category) {
    final cs = Theme.of(context).colorScheme;
    switch (category) {
      case '누수':
        return Colors.blue;
      case '화장실':
        return Colors.teal;
      case '배관':
        return Colors.indigo;
      case '난방':
        return Colors.orange;
      case '주방':
        return Colors.redAccent;
      case '리모델링':
        return cs.primary;
      default:
        return cs.secondary;
    }
  }

  Future<int> _fetchMyOrderCount(BuildContext context) async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final orderService = Provider.of<OrderService>(context, listen: false);

      if (auth.currentUser != null) {
        // 우선 전체 로드 후 전화번호 기준 필터 (MyEstimates와 동일 전략)
        await orderService.loadOrders();
        final all = orderService.orders;
        final user = auth.currentUser!;
        final phone = (user.phoneNumber ?? '').replaceAll(RegExp(r'[-\s()]'), '');
        if (phone.isNotEmpty) {
          return all.where((o) => o.customerPhone.replaceAll(RegExp(r'[-\s()]'), '') == phone).length;
        }
        // 폰번호 없으면 customerId 기반
        await orderService.loadOrders(customerId: user.id);
        return orderService.orders.length;
      } else {
        // 비로그인: 세션ID 기반
        final prefs = await SharedPreferences.getInstance();
        final sessionId = prefs.getString('allsuri_session_id');
        if (sessionId == null || sessionId.isEmpty) return 0;
        await orderService.loadOrders(sessionId: sessionId);
        return orderService.orders.length;
      }
    } catch (_) {
      return 0;
    }
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
