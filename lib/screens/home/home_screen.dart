import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/customer_dashboard.dart';
import '../../widgets/business_dashboard.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // 사업자가 로그인한 경우 자동으로 대시보드로 이동
        if (authService.isAuthenticated && authService.currentUser?.role == 'business') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const BusinessDashboard(),
              ),
              (route) => false,
            );
          });
        }
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('AllSuri'),
            actions: authService.isAuthenticated
                ? [
                    TextButton(
                      onPressed: () {
                        authService.signOut();
                      },
                      child: const Text('로그아웃'),
                    ),
                  ]
                : null,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 앱 로고 및 제목
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.home_repair_service,
                      size: 80,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '올수리에 오신 것을\n환영합니다!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authService.isAuthenticated
                        ? (authService.currentUser?.role == 'business'
                            ? '${authService.currentUser?.name ?? "사업자"} 님, 올수리에 오신 것을 환영합니다!'
                            : '어떤 서비스를 이용하시겠습니까?')
                        : '전문가와 연결하여\n빠르고 안전한 서비스를 받아보세요',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // 고객 버튼 (사업자가 로그인한 경우 숨김)
                  if (!(authService.isAuthenticated && 
                        authService.currentUser?.role == 'business'))
                    FilledButton.icon(
                      onPressed: () async {
                        if (!authService.isAuthenticated) {
                          // 익명 로그인 후 고객 대시보드로 이동
                          await authService.signInAnonymously();
                        }
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CustomerDashboard(),
                            ),
                            (route) => false, // 모든 이전 화면 제거
                          );
                        }
                      },
                      icon: const Icon(Icons.request_quote),
                      label: const Text(
                        '견적 내기 (고객)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  
                  // 사업자가 로그인한 경우에만 간격 추가
                  if (!(authService.isAuthenticated && 
                        authService.currentUser?.role == 'business'))
                    const SizedBox(height: 16),
                  
                  // 사업자 버튼
                  OutlinedButton.icon(
                    onPressed: () {
                      if (authService.isAuthenticated) {
                        // 이미 로그인된 경우 바로 사업자 대시보드로 이동
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BusinessDashboard(),
                          ),
                          (route) => false, // 모든 이전 화면 제거
                        );
                      } else {
                        // 로그인이 필요한 경우 로그인 다이얼로그 표시
                        _showBusinessLoginDialog(context);
                      }
                    },
                    icon: const Icon(Icons.business),
                    label: Text(
                      authService.isAuthenticated
                          ? '사업자 대시보드'
                          : '사업자 로그인',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
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
