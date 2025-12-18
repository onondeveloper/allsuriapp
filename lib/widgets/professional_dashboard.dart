import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../screens/business/estimate_requests_screen.dart';
import '../screens/business/estimate_management_screen.dart';
import '../screens/business/transfer_estimate_screen.dart';
import '../screens/notification/notification_screen.dart';
import '../screens/business/job_management_screen.dart';
import '../screens/business/order_marketplace_screen.dart';
import '../screens/business/my_order_management_screen.dart';
import '../screens/business/pending_approval_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/marketplace_service.dart';
import '../services/order_service.dart';
import '../services/api_service.dart';
import '../screens/home/home_screen.dart';
import '../widgets/bottom_navigation.dart';
import '../screens/community/community_board_screen.dart';

/// 프로페셔널 스타일 C - 데이터 중심 대시보드
class ProfessionalDashboard extends StatefulWidget {
  const ProfessionalDashboard({Key? key}) : super(key: key);

  @override
  State<ProfessionalDashboard> createState() => _ProfessionalDashboardState();
}

class _ProfessionalDashboardState extends State<ProfessionalDashboard> {
  int _currentIndex = 0;
  final MarketplaceService _market = MarketplaceService();
  
  late Future<Map<String, int>> _dashboardDataFuture;
  
  RealtimeChannel? _marketplaceChannel;
  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
    _refreshData();
  }

  void _setupRealtimeListeners() {
    _marketplaceChannel = Supabase.instance.client
        .channel('public:marketplace_listings')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'marketplace_listings',
          callback: (payload) {
            if (mounted) _refreshData();
          },
        )
        .subscribe();

    _ordersChannel = Supabase.instance.client
        .channel('public:orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            if (mounted) _refreshData();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _marketplaceChannel?.unsubscribe();
    _ordersChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _dashboardDataFuture = _loadDashboardData();
    });
  }

  Future<Map<String, int>> _loadDashboardData() async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🚀 [ProfessionalDashboard] 대시보드 데이터 로드 시작');
      
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;
      
      print('   userId: $currentUserId');
      
      if (currentUserId == null) {
        print('❌ [ProfessionalDashboard] userId가 null');
        return {};
      }
      
      // 병렬로 데이터 로드
      print('   병렬 로드 시작...');
      final results = await Future.wait([
        _getCompletedJobsCount(currentUserId),
        _getInProgressJobsCount(currentUserId),
        _getNewOrdersCount(currentUserId),
        _getMyBidsCount(currentUserId),
        _getMyOrdersCount(currentUserId),
      ]);
      
      final data = {
        'completed': results[0],
        'inProgress': results[1],
        'newOrders': results[2],
        'myBids': results[3],
        'myOrders': results[4],
      };
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ [ProfessionalDashboard] 로드 완료:');
      print('   완료한 공사: ${data['completed']}');
      print('   진행 중: ${data['inProgress']}');
      print('   새 오더: ${data['newOrders']}');
      print('   입찰 대기 중: ${data['myBids']}');
      print('   내 오더: ${data['myOrders']}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return data;
    } catch (e) {
      print('❌ [_loadDashboardData] 에러: $e');
      return {};
    }
  }

  Future<int> _getCompletedJobsCount(String userId) async {
    try {
      // 실제 완료된 공사 카운트 (매출 페이지와 동일한 로직)
      final response = await Supabase.instance.client
          .from('jobs')
          .select('id')
          .eq('assigned_business_id', userId)
          .inFilter('status', ['completed', 'awaiting_confirmation'])
          .count(CountOption.exact);
      
      print('🔍 [_getCompletedJobsCount] 완료한 공사: ${response.count}개');
      return response.count;
    } catch (e) {
      print('❌ [_getCompletedJobsCount] 에러: $e');
      return 0;
    }
  }

  // ⚡ 성능 개선: count 쿼리 최적화
  Future<int> _getInProgressJobsCount(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('jobs')
          .select('id')
          .eq('assigned_business_id', userId)
          .eq('status', 'in_progress')
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      print('❌ [_getInProgressJobsCount] 에러: $e');
      return 0;
    }
  }

  // ⚡ 성능 개선: 서버사이드 필터링 및 count 쿼리 최적화
  Future<int> _getNewOrdersCount(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('marketplace_listings')
          .select('id')
          .inFilter('status', ['open', 'created'])
          .neq('posted_by', userId)
          .count(CountOption.exact);
      
      return response.count;
    } catch (e) {
      print('❌ [_getNewOrdersCount] 에러: $e');
      return 0;
    }
  }

  // ⚡ 성능 개선: 이중 쿼리 제거, 서버에서 직접 count
  Future<int> _getMyBidsCount(String userId) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔍 [_getMyBidsCount] 입찰 대기 중 카운트 시작');
      print('   userId: $userId');
      print('   현재 시각: ${DateTime.now()}');
      
      // 디버그: 모든 입찰 먼저 확인 (더 상세한 정보)
      final allBids = await Supabase.instance.client
          .from('order_bids')
          .select('id, listing_id, bidder_id, status, created_at')
          .eq('bidder_id', userId)
          .order('created_at', ascending: false);
      
      print('   전체 입찰: ${allBids.length}개');
      if (allBids.isEmpty) {
        print('   ⚠️ 이 사용자의 입찰이 order_bids 테이블에 없습니다!');
      } else {
        for (var bid in allBids) {
          print('      입찰 ID: ${bid['id']}');
          print('         listing_id: ${bid['listing_id']}');
          print('         status: ${bid['status']}');
          print('         created_at: ${bid['created_at']}');
        }
      }
      
      // pending 상태만 카운트
      final response = await Supabase.instance.client
          .from('order_bids')
          .select('listing_id')
          .eq('bidder_id', userId)
          .eq('status', 'pending')
          .count(CountOption.exact);
      
      print('   ✅ pending 상태 입찰: ${response.count}개');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return response.count;
    } catch (e) {
      print('❌ [_getMyBidsCount] 에러: $e');
      return 0;
    }
  }

  Future<int> _getMyOrdersCount(String userId) async {
    try {
      return await _market.countListings(
        status: 'all',
        postedBy: userId,
      );
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.currentUser;
        final businessStatus = user?.businessStatus?.toLowerCase() ?? '';
        final isApproved = businessStatus == 'approved';
        
        if (!isApproved) {
          return const PendingApprovalScreen();
        }
        
        final businessName = (user?.businessName != null && user!.businessName!.trim().isNotEmpty)
            ? user.businessName!
            : (user?.name ?? "사업자");
        
        return WillPopScope(
          onWillPop: () async {
            // 대시보드가 홈이므로 뒤로가기 방지
            return false;
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: _buildAppBar(context, user),
            body: FutureBuilder<Map<String, int>>(
              future: _dashboardDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final data = snapshot.data ?? {};
                return RefreshIndicator(
                  onRefresh: () async => _refreshData(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAdBanner(context),
                        const SizedBox(height: 20),
                        _buildKPICards(data),
                        const SizedBox(height: 24),
                        _buildMainMenu(context, data),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
            bottomNavigationBar: BottomNavigation(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
              },
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, dynamic user) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.dashboard, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            '올수리 프로',
            style: TextStyle(
              color: Color(0xFF1E3A8A),
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ],
      ),
      actions: [
        FutureBuilder<int>(
          future: NotificationService().getUnreadCount(user?.id ?? ''),
          builder: (context, snapshot) {
            final unread = snapshot.data ?? 0;
            
            // 디버그 로그
            if (snapshot.connectionState == ConnectionState.done) {
              print('🔔 [Dashboard] 읽지 않은 알림: $unread개');
            }
            
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1E3A8A)),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationScreen()),
                    );
                    // 알림 화면에서 돌아오면 대시보드 새로고침
                    if (mounted) {
                      setState(() {
                        _dashboardDataFuture = _loadDashboardData();
                      });
                    }
                  },
                ),
                if (unread > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unread > 9 ? '9+' : unread.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.person_outline, color: Color(0xFF1E3A8A)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildKPICards(Map<String, int> data) {
    return Row(
      children: [
        Expanded(
          child: _buildKPICard(
            '완료한 공사',
            data['completed'] ?? 0,
            Icons.check_circle,
            const Color(0xFFCCF5F5), // 아주 연한 민트 (초연한 파스텔)
            null, // trend
            () {
              // 완료된 공사 필터로 내 공사 관리 화면 열기
              Navigator.push(context, MaterialPageRoute(builder: (context) => const JobManagementScreen()));
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKPICard(
            '진행 중',
            data['inProgress'] ?? 0,
            Icons.construction,
            const Color(0xFFEDE9FE), // 아주 연한 라벤더 (초연한 파스텔)
            null,
            () {
              // 진행 중 필터로 내 공사 관리 화면 열기
              Navigator.push(context, MaterialPageRoute(builder: (context) => const JobManagementScreen()));
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKPICard(
            '낙찰 대기',
            data['myBids'] ?? 0,
            Icons.access_time,
            const Color(0xFFFEE2E2), // 아주 연한 핑크 (초연한 파스텔)
            null,
            () {
              // 오더 마켓플레이스로 이동 (내가 입찰한 오더들)
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderMarketplaceScreen(showSuccessMessage: false)));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, int value, IconData icon, Color color, String? trend, VoidCallback onTap) {
    // 색상에 따라 그라데이션 및 텍스트 색상 결정 (초연한 파스텔 톤)
    List<Color> gradientColors;
    Color textColor;
    Color iconColor;
    
    if (color == const Color(0xFFCCF5F5)) {
      // 완료한 공사 - 아주 연한 민트
      gradientColors = [const Color(0xFFCCF5F5), const Color(0xFFB2F5EA)];
      textColor = const Color(0xFF0D9488); // 진한 민트 (가독성)
      iconColor = const Color(0xFF14B8A6);
    } else if (color == const Color(0xFFEDE9FE)) {
      // 진행 중 - 아주 연한 라벤더
      gradientColors = [const Color(0xFFEDE9FE), const Color(0xFFDDD6FE)];
      textColor = const Color(0xFF7C3AED); // 진한 보라 (가독성)
      iconColor = const Color(0xFF8B5CF6);
    } else if (color == const Color(0xFFFEE2E2)) {
      // 낙찰 대기 - 아주 연한 핑크
      gradientColors = [const Color(0xFFFEE2E2), const Color(0xFFFECACA)];
      textColor = const Color(0xFFDC2626); // 진한 핑크/레드 (가독성)
      iconColor = const Color(0xFFEF4444);
    } else {
      gradientColors = [color, color];
      textColor = Colors.white;
      iconColor = Colors.white;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08), // 초연한 파스텔 톤에 맞게 그림자 더 연하게
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15), // 아이콘 색상 톤의 연한 배경
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: textColor,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: textColor.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (trend != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildMainMenu(BuildContext context, Map<String, int> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildMenuItem(
          context,
          '오더 마켓플레이스',
          '새로운 공사 찾기',
          Icons.shopping_bag_outlined,
          const Color(0xFFF59E0B),
          data['newOrders'] ?? 0,
          () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OrderMarketplaceScreen(showSuccessMessage: false)),
            );
            if (!mounted) return;
            _refreshData();
          },
        ),
        const SizedBox(height: 12),
        _buildMenuItem(
          context,
          '내 공사 관리',
          '낙찰받은 공사 확인',
          Icons.construction_outlined,
          const Color(0xFF10B981),
          data['inProgress'] ?? 0,
          () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const JobManagementScreen()));
          },
        ),
        const SizedBox(height: 12),
        _buildMenuItem(
          context,
          '내 오더 관리',
          '등록한 오더 확인',
          Icons.assignment_outlined,
          const Color(0xFF3B82F6),
          data['myOrders'] ?? 0,
          () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MyOrderManagementScreen()));
          },
        ),
        const SizedBox(height: 12),
        _buildMenuItem(
          context,
          '커뮤니티',
          '동료들과 소통하기',
          Icons.people_outline,
          const Color(0xFF7C3AED),
          null,
          () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const CommunityBoardScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    int? badge,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null && badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildAdBanner(BuildContext context) {
    // 2개의 광고 슬라이드
    final ads = [
      {'title': '광고 1'},
      {'title': '광고 2'},
    ];

    return SizedBox(
      height: 80,
      child: _DashboardAdCarousel(ads: ads),
    );
  }

}

class _DashboardAdCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> ads;
  const _DashboardAdCarousel({Key? key, required this.ads}) : super(key: key);

  @override
  State<_DashboardAdCarousel> createState() => _DashboardAdCarouselState();
}

class _DashboardAdCarouselState extends State<_DashboardAdCarousel> {
  final PageController _controller = PageController();
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_current < widget.ads.length - 1) {
        _current++;
      } else {
        _current = 0;
      }

      if (_controller.hasClients) {
        _controller.animateToPage(
          _current,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showAdInquiry() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('광고 문의: 010-8345-1912'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                _current = index;
              });
            },
            itemCount: widget.ads.length,
            itemBuilder: (context, index) {
              final ad = widget.ads[index];
              return GestureDetector(
                onTap: _showAdInquiry,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Text(
                      ad['title'] ?? '광고 ${index + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
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
          children: widget.ads.asMap().entries.map((entry) {
            return Container(
              width: 6.0,
              height: 6.0,
              margin: const EdgeInsets.symmetric(horizontal: 2.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _current == entry.key
                    ? const Color(0xFF1E3A8A)
                    : Colors.grey.withOpacity(0.4),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}


