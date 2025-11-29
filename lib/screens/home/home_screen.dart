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
import '../../services/api_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // 역할 선택이 필요한 경우
        if (authService.isAuthenticated && authService.needsRoleSelection) {
          return const RoleSelectionScreen();
        }
        
        // 사업자: 직접 해당 화면 반환
        if (authService.isAuthenticated && authService.currentUser?.role == 'business') {
          final u = authService.currentUser!;
          final hasBusinessName = (u.businessName != null && u.businessName!.trim().isNotEmpty);
          final status = (u.businessStatus ?? 'pending').toLowerCase();
          
          print('🔍 [HomeScreen] 사업자 사용자 정보:');
          print('   - ID: ${u.id}');
          print('   - Business Status: $status');
          
          if (status == 'approved') {
            return const BusinessDashboard();
          }
          
          if (!hasBusinessName) {
            return const BusinessProfileScreen();
          }
          
          return const BusinessPendingScreen();
        }
        
        return WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                '올수리',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: false,
              actions: authService.isAuthenticated
                  ? [
                      IconButton(
                        tooltip: '로그아웃',
                        onPressed: () => authService.signOut(),
                        icon: const Icon(Icons.logout, color: Colors.black),
                      ),
                    ]
                  : null,
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final buttonWidth = width * 0.6; // 너비 60%
                  
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20),
                              
                              // 1. 상단 텍스트 (기존 스타일로 롤백)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '환영합니다!',
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '전문가와 연결하여 빠르고 안전한\n서비스를 받아보세요',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey[600],
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const Spacer(),
                              
                              // 2. 광고 대체 ("Buy me a coffee")
                              _buildBuyMeCoffee(context),
                              
                              const Spacer(),
                              
                              // 3. 카카오 로그인 버튼 (너비 60%)
                              if (!authService.isAuthenticated)
                                SizedBox(
                                  width: buttonWidth,
                                  child: InkWell(
                                    onTap: () => _showBusinessLoginDialog(context),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      'assets/images/kakao_login_large_narrow.png',
                                      fit: BoxFit.fitWidth,
                                    ),
                                  ),
                                ),
                              
                              const SizedBox(height: 40),
                              
                              // 4. 하단 푸터 (서비스 특징) - 유지
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildFeatureItem(Icons.verified_user_outlined, '신뢰할 수 있는\n전문가'),
                                  Container(height: 30, width: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 24)),
                                  _buildFeatureItem(Icons.speed, '빠르고 간편한\n매칭'),
                                  Container(height: 30, width: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 24)),
                                  _buildFeatureItem(Icons.thumb_up_outlined, '만족스러운\n결과'),
                                ],
                              ),
                              
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBuyMeCoffee(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('후원 기능 준비 중입니다! ☕')),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.coffee_rounded, size: 48, color: Colors.brown[400]),
            const SizedBox(height: 16),
            const Text(
              'Buy me a coffee',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '개발자에게 커피 한 잔 후원하기',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
            height: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerMenu(BuildContext context) {
    // ... (기존 코드 유지 가능하지만 현재 사용 안함)
    return const SizedBox.shrink(); 
  }

  Future<int> _fetchMyOrderCount(BuildContext context) async {
    try {
      return 0; // 임시 반환
    } catch (_) {
      return 0;
    }
  }

  void _showBusinessLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사업자 로그인'),
        content: const Text('카카오 계정으로 로그인하여 사업자 기능을 이용하세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // 카카오 로그인
                await Provider.of<AuthService>(context, listen: false).signInWithKakao();
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
            child: const Text('카카오 로그인'),
          ),
        ],
      ),
    );
  }
}
