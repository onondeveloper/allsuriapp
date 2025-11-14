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
import 'package:webview_flutter/webview_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // 디버그 로그 제거
        
        // 역할 선택이 필요한 경우
        if (authService.isAuthenticated && authService.needsRoleSelection) {
          return const RoleSelectionScreen();
        }
        
        // 사업자: 직접 해당 화면 반환 (네비게이션 대신 위젯 교체로 라우팅 혼선 방지)
        if (authService.isAuthenticated && authService.currentUser?.role == 'business') {
          final u = authService.currentUser!;
          final hasBusinessName = (u.businessName != null && u.businessName!.trim().isNotEmpty);
          final status = (u.businessStatus ?? 'pending').toLowerCase();
          
          // 디버그 로그
          print('🔍 [HomeScreen] 사업자 사용자 정보:');
          print('   - ID: ${u.id}');
          print('   - Name: ${u.name}');
          print('   - Business Status (원본): ${u.businessStatus}');
          print('   - Business Status (소문자): $status');
          print('   - Business Name: ${u.businessName}');
          print('   - Has Business Name: $hasBusinessName');
          
          // Admin에서 승인된 경우 프로필 완성 여부와 관계없이 바로 대시보드로 이동
          if (status == 'approved') {
            print('   ✅ 승인됨 -> BusinessDashboard로 이동');
            return const BusinessDashboard();
          }
          
          // 승인되지 않았고 프로필이 비어있으면 프로필 등록 페이지로
          if (!hasBusinessName) {
            print('   📝 프로필 미완성 -> BusinessProfileScreen으로 이동');
            return const BusinessProfileScreen();
          }
          
          // 승인 대기 중
          print('   ⏳ 승인 대기 중 -> BusinessPendingScreen으로 이동');
          return const BusinessPendingScreen();
        }
        
        return WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('올수리'),
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
                            height: 56, // 44 -> 56으로 높이 증가
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white70, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CustomerMyEstimatesScreen()),
                                );
                              },
                              icon: const Icon(Icons.assignment_turned_in_outlined, color: Colors.white, size: 22),
                              label: const Text(
                                '내 견적 바로가기',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 카테고리 칩 / 그리드 (아이콘 커스터마이즈) - 임시 주석 처리
                /* 
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
                            elevation: 1,
                            shadowColor: Colors.black.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            color: Theme.of(context).colorScheme.surface,
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
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            color.withOpacity(0.15),
                                            color.withOpacity(0.08),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(_categoryIcon(c), size: 36, color: color),
                                    ),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        c,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.2,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
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
                */

                // const SizedBox(height: 24),

                // 광고 섹션 (카테고리 버튼 크기로 축소)
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 80, // 카테고리 버튼과 비슷한 높이로 축소
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey[400]!,
                        width: 1,
                      ),
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) {
                            return Dialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.campaign_outlined, size: 24),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Buy me a coffee',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.asset(
                                        'assets/images/logo.png',
                                        width: 220,
                                        fit: BoxFit.contain,
                                        errorBuilder: (c, e, s) {
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '광고 문의: 010-8345-1912.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 16),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(),
                                        child: const Text('닫기'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.campaign_outlined,
                              size: 24,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Buy me a coffee',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 하단으로 밀어내기
                const SizedBox(height: 30),

                // Kakao 공식 스타일 버튼 (노란색, 카카오톡 우선 자동 로그인)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        try {
                          if (authService.isAuthenticated) {
                            if (authService.currentUser?.role != 'business') {
                              await authService.updateRole('business');
                            }
                            // 화면은 자동으로 BusinessDashboard로 전환됨 (HomeScreen 빌더에서 역할에 따라 위젯 교체)
                            return;
                          }

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
                                        // 불꽃 애니메이션 효과
                                        TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          duration: const Duration(milliseconds: 1500),
                                          builder: (context, value, child) {
                                            return Transform.scale(
                                              scale: 0.8 + (value * 0.2),
                                              child: Opacity(
                                                opacity: 0.6 + (value * 0.4),
                                                child: const Text(
                                                  '🔥',
                                                  style: TextStyle(fontSize: 64),
                                                ),
                                              ),
                                            );
                                          },
                                          onEnd: () {
                                            // 애니메이션 반복을 위해 (선택사항)
                                          },
                                        ),
                                        const SizedBox(height: 24),
                                        const CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFEE500)),
                                        ),
                                        const SizedBox(height: 24),
                                        const Text(
                                          '사업자님의 열정을 예열 중입니다...',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '카카오톡으로 안전하게 연결 중',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
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

                          // 카카오톡 설치 시 앱 자동 로그인, 미설치 시 카카오계정 로그인
                          final ok = await Provider.of<AuthService>(context, listen: false).signInWithKakao();
                          
                          // 로딩 다이얼로그 닫기
                          if (context.mounted) {
                            Navigator.of(context, rootNavigator: true).pop();
                          }
                          
                          if (ok) {
                            await Provider.of<AuthService>(context, listen: false).updateRole('business');
                            // 화면은 자동으로 BusinessDashboard로 전환됨 (HomeScreen 빌더에서 역할에 따라 위젯 교체)
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('카카오 로그인에 실패했습니다')),
                              );
                            }
                          }
                        } catch (e) {
                          // 로딩 다이얼로그 닫기 (에러 시에도)
                          if (context.mounted) {
                            Navigator.of(context, rootNavigator: true).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('오류가 발생했습니다: $e')),
                            );
                          }
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          alignment: Alignment.center,
                          color: Colors.transparent,
                          child: Image.asset(
                            'assets/images/kakao_login_image.png', // 제공된 이미지로 교체
                            fit: BoxFit.none, // 원본 크기 유지
                            filterQuality: FilterQuality.high,
                            errorBuilder: (context, error, stack) {
                              // 에셋이 없으면 노란 배경 + 로고만(원본 크기) 표시
                              return Container(
                                color: const Color(0xFFFEE500),
                                alignment: Alignment.center,
                                child: Image.asset(
                                  'assets/images/kakao_logo.png',
                                  fit: BoxFit.none,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
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
            child: const Text('Google 로그인'),
          ),
        ],
      ),
    );
  }
}

class _AdsCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  const _AdsCarousel({required this.items});

  @override
  State<_AdsCarousel> createState() => _AdsCarouselState();
}

class _AdsCarouselState extends State<_AdsCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _current = 0;
  final Set<String> _impressed = {};
  late final ApiService _api;

  @override
  void initState() {
    super.initState();
    _api = ApiService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendImpressionIfNeeded(0);
    });
    // Auto rotate every 5s
    _startAutoRotate();
  }

  void _startAutoRotate() {
    Future.doWhile(() async {
      if (!mounted) return false;
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;
      final next = (_current + 1) % widget.items.length;
      _pageController.animateToPage(next, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      return true;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 320, // 카테고리 영역을 대체하도록 크기 확대
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) {
              setState(() => _current = idx);
              _sendImpressionIfNeeded(idx);
            },
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final ad = widget.items[index];
              final adId = (ad['id']?.toString() ?? '');
              final title = (ad['title']?.toString() ?? '광고');
              final htmlPath = (ad['html_path']?.toString() ?? '');
              return GestureDetector(
                onTap: () async {
                  if (adId.isNotEmpty) {
                    await _api.trackAdClick(adId);
                  }
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => _AdFullScreenPage(title: title, htmlPath: htmlPath)),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.coffee_rounded,
                          size: 64,
                          color: Colors.brown.shade400,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Buy Me a Coffee',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '☕',
                          style: const TextStyle(fontSize: 32),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.items.length, (i) {
            final active = i == _current;
            return Container(
              width: active ? 10 : 6,
              height: active ? 10 : 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                shape: BoxShape.circle,
              ),
            );
          }),
        )
      ],
    );
  }

  Future<void> _sendImpressionIfNeeded(int idx) async {
    if (idx < 0 || idx >= widget.items.length) return;
    final ad = widget.items[idx];
    final adId = (ad['id']?.toString() ?? '');
    if (adId.isEmpty) return;
    if (_impressed.contains(adId)) return;
    _impressed.add(adId);
    await _api.trackAdImpression(adId);
  }
}

class _AdFullScreenPage extends StatelessWidget {
  final String title;
  final String htmlPath; // e.g., /ads/summer_promo.html
  const _AdFullScreenPage({super.key, required this.title, required this.htmlPath});

  @override
  Widget build(BuildContext context) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          final url = req.url;
          final allowed = url.startsWith('https://api.allsuriapp.com/ads') ||
              url.startsWith('http://10.0.2.2:3001/ads');
          return allowed ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(_adUrl()));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: WebViewWidget(controller: controller)),
    );
  }

  String _adUrl() {
    // Use release vs debug base to load static ad HTML served by backend
    if (bool.fromEnvironment('dart.vm.product')) {
      return 'https://api.allsuriapp.com$htmlPath';
    }
    return 'http://10.0.2.2:3001$htmlPath';
  }
}
