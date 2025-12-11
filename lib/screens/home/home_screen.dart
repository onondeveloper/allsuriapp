import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../../widgets/customer_dashboard.dart';
import '../../widgets/interactive_card.dart';
import '../../widgets/business_dashboard.dart';
import '../../widgets/professional_dashboard.dart';
import '../business/business_profile_screen.dart';
import '../business/business_pending_screen.dart';
import '../role_selection_screen.dart';
import '../../models/order.dart' as app_models;
import '../customer/create_request_screen.dart';
import '../customer/my_estimates_screen.dart';
import '../../services/api_service.dart';
import '../onboarding/onboarding_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCheckingOnboarding = true;
  bool _shouldShowOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final completed = await OnboardingScreen.isOnboardingCompleted();
    if (mounted) {
      setState(() {
        _shouldShowOnboarding = !completed;
        _isCheckingOnboarding = false;
      });
    }
  }

  void _completeOnboarding() {
    setState(() {
      _shouldShowOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 온보딩 체크 중
    if (_isCheckingOnboarding) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 온보딩이 필요한 경우
    if (_shouldShowOnboarding) {
      return OnboardingScreen(onComplete: _completeOnboarding);
    }

    // 메인 화면
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
            return const ProfessionalDashboard();
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
                              
                              // 1. 상단 환영 메시지 (디자인 개선)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '환영합니다!',
                                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF222B45),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '전문가와 연결하여\n빠르고 안전한 서비스를\n받아보세요',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Colors.grey[600],
                                              height: 1.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.handyman_rounded,
                                        size: 48,
                                        color: Theme.of(context).primaryColor,
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
                                    onTap: () => _handleKakaoLogin(context), // 바로 로그인 실행
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

  Future<void> _handleKakaoLogin(BuildContext context) async {
    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 애니메이션 효과 (아이콘 바운스 등)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(seconds: 1),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, -10 * (1 - value).abs() * (value < 0.5 ? 1 : -1)), // 간단한 바운스
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE500).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.work_outline, size: 48, color: Color(0xFFFEE500)),
                        ),
                      );
                    },
                    onEnd: () {}, // 반복하려면 StatefulWidget 필요
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFEE500)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '일감을 챙겨 오고 있어요!! 🏃',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '잠시만 기다려주세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      // 카카오 로그인 실행
      await Provider.of<AuthService>(context, listen: false).signInWithKakao();
      
      if (context.mounted) {
        // 로그인 성공 시 로딩 닫기
        Navigator.of(context, rootNavigator: true).pop();
        
        // 화면은 자동으로 BusinessDashboard로 전환됨 (HomeScreen 빌더에서 역할에 따라 위젯 교체)
      }
    } catch (e) {
      if (context.mounted) {
        // 로딩 닫기
        Navigator.of(context, rootNavigator: true).pop();
        
        // 에러 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
