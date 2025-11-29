import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../../services/ad_service.dart';
import '../../models/ad.dart';
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
        // 역할 선택이 필요한 경우
        if (authService.isAuthenticated && authService.needsRoleSelection) {
          return const RoleSelectionScreen();
        }
        
        // 사업자: 직접 해당 화면 반환 (네비게이션 대신 위젯 교체로 라우팅 혼선 방지)
        if (authService.isAuthenticated && authService.currentUser?.role == 'business') {
          final u = authService.currentUser!;
          final hasBusinessName = (u.businessName != null && u.businessName!.trim().isNotEmpty);
          final status = (u.businessStatus ?? 'pending').toLowerCase();
          
          print('🔍 [HomeScreen] 사업자 사용자 정보:');
          print('   - ID: ${u.id}');
          print('   - Business Status: $status');
          
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
            backgroundColor: Colors.white,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final contentWidth = width - 48; // 좌우 패딩 24씩
                  
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
                              const SizedBox(height: 40),
                              
                              // 1. 상단 환영 메시지
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '올수리에\n오신 것을 환영합니다',
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF222B45),
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '전문가와 연결하여 빠르고 안전한\n서비스를 받아보세요',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.grey[600],
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const Spacer(),
                              
                              // 2. 광고 배너 (1:1 비율)
                              FutureBuilder<List<Ad>>(
                                future: AdService().getAdsByLocation('home_banner'),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                    // 광고 없을 때 기본 이미지 표시
                                    return Container(
                                      width: contentWidth,
                                      height: contentWidth,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                                      ),
                                    );
                                  }
                                  return SizedBox(
                                    width: contentWidth,
                                    height: contentWidth + 30, // 인디케이터 공간 확보
                                    child: _BannerSlider(ads: snapshot.data!),
                                  );
                                },
                              ),
                              
                              const Spacer(),
                              
                              // 3. 카카오 로그인 버튼
                              if (!authService.isAuthenticated)
                                InkWell(
                                  onTap: () => _showBusinessLoginDialog(context),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    'assets/images/kakao_login_large_narrow.png',
                                    width: contentWidth,
                                    fit: BoxFit.fitWidth,
                                  ),
                                ),
                              
                              const SizedBox(height: 40),
                              
                              // 4. 하단 푸터 (서비스 특징)
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
    return Column(
      children: [
        InteractiveCard(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateRequestScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_circle_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '견적 요청하기',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '필요한 수리 내용을 알려주세요',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        InteractiveCard(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CustomerMyEstimatesScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.list_alt,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '내 견적 보기',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '받은 견적을 확인해보세요',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<int> _fetchMyOrderCount(BuildContext context) async {
    try {
      return 0; // 임시 반환
    } catch (_) {
      return 0;
    }
  }

  Color _categoryColor(BuildContext context, String category) {
    switch (category) {
      case '수도':
        return Colors.blue;
      case '전기':
        return Colors.orange;
      case '난방':
        return Colors.red;
      case '창호':
        return Colors.cyan;
      case '방수':
        return Colors.indigo;
      case '도배/장판':
        return Colors.purple;
      case '인테리어':
        return Colors.pink;
      case '기타':
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case '수도':
        return Icons.water_drop_outlined;
      case '전기':
        return Icons.lightbulb_outline;
      case '난방':
        return Icons.thermostat_outlined;
      case '창호':
        return Icons.window_outlined;
      case '방수':
        return Icons.invert_colors_off_outlined;
      case '도배/장판':
        return Icons.layers_outlined;
      case '인테리어':
        return Icons.weekend_outlined;
      case '기타':
        return Icons.more_horiz;
      default:
        return Icons.handyman_outlined;
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

class _BannerSlider extends StatefulWidget {
  final List<Ad> ads;
  const _BannerSlider({Key? key, required this.ads}) : super(key: key);

  @override
  State<_BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<_BannerSlider> {
  int _current = 0;
  final PageController _controller = PageController(viewportFraction: 1.0);

  Future<void> _launchUrl(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      print('❌ 링크 열기 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (idx) {
              setState(() => _current = idx);
            },
            itemCount: widget.ads.length,
            itemBuilder: (context, index) {
              final ad = widget.ads[index];
              return GestureDetector(
                onTap: () {
                  if (ad.linkUrl != null && ad.linkUrl!.isNotEmpty) {
                    _launchUrl(ad.linkUrl!);
                  }
                },
                child: Container(
                  margin: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: CachedNetworkImage(
                      imageUrl: ad.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.ads.length > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.ads.length, (i) {
              final active = i == _current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: active ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: active ? Theme.of(context).colorScheme.primary : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          )
        ]
      ],
    );
  }
}
