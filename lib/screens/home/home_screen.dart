import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/customer_dashboard.dart';
import '../../widgets/business_dashboard.dart';
import '../business/business_profile_screen.dart';
import '../business/business_pending_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // 사업자 라우팅 분기: 정보 미입력 -> 프로필, 승인대기/거절 -> 대기 화면, 승인됨 -> 대시보드
        if (authService.isAuthenticated && authService.currentUser?.role == 'business') {
          final u = authService.currentUser!;
          final hasBusinessName = (u.businessName != null && u.businessName!.trim().isNotEmpty);
          final status = (u.businessStatus ?? 'pending').toLowerCase();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!hasBusinessName) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
                (route) => false,
              );
            } else if (status != 'approved') {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const BusinessPendingScreen()),
                (route) => false,
              );
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const BusinessDashboard()),
                (route) => false,
              );
            }
          });
        }
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('AllSuri'),
            actions: authService.isAuthenticated
                ? [
                    IconButton(
                      tooltip: '로그아웃',
                      onPressed: () {
                        authService.signOut();
                      },
                      icon: const Icon(Icons.logout),
                    ),
                  ]
                : null,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                // HERO
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        Theme.of(context).colorScheme.tertiary.withOpacity(0.10),
                      ],
                    ),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 44,
                            height: 44,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.home_repair_service,
                              size: 40,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '올수리에 오신 것을 환영합니다',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              authService.isAuthenticated
                                  ? (authService.currentUser?.role == 'business'
                                      ? '${authService.currentUser?.name ?? "사업자"}님, 바로 시작해볼까요?'
                                      : '원하는 서비스를 빠르게 연결해 드려요')
                                  : '전문가와 연결하여 빠르고 안전한 서비스를 받아보세요',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ACTIONS
                if (!(authService.isAuthenticated &&
                    authService.currentUser?.role == 'business'))
                  FilledButton.icon(
                    onPressed: () async {
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CustomerDashboard(),
                        ),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.request_quote),
                    label: const Text(
                      '견적 내기 (고객)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),

                if (!(authService.isAuthenticated &&
                    authService.currentUser?.role == 'business'))
                  const SizedBox(height: 12),

                FilledButton.tonalIcon(
                  onPressed: () {
                    if (authService.isAuthenticated) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BusinessDashboard(),
                        ),
                        (route) => false,
                      );
                    } else {
                      _showBusinessLoginDialog(context);
                    }
                  },
                  icon: const Icon(Icons.business),
                  label: Text(
                    authService.isAuthenticated ? '사업자 대시보드' : '사업자 로그인',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
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
                await Provider.of<AuthService>(context, listen: false).signInWithGoogle();
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
