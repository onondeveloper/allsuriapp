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
import '../services/ad_service.dart';
import '../models/ad.dart';
import '../screens/home/home_screen.dart';
import '../widgets/bottom_navigation.dart';
import '../screens/community/community_board_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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
  late Future<List<Ad>> _adFuture;
  
  RealtimeChannel? _marketplaceChannel;
  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();
    _adFuture = AdService().getAdsByLocation('dashboard_banner');
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
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;
      
      if (currentUserId == null) return {};
      
      // 병렬로 데이터 로드
      final results = await Future.wait([
        _getCompletedJobsCount(currentUserId),
        _getInProgressJobsCount(currentUserId),
        _getNewOrdersCount(currentUserId),
        _getMyBidsCount(currentUserId),
        _getMyOrdersCount(currentUserId),
      ]);
      
      return {
        'completed': results[0],
        'inProgress': results[1],
        'newOrders': results[2],
        'myBids': results[3],
        'myOrders': results[4],
      };
    } catch (e) {
      print('❌ [_loadDashboardData] 에러: $e');
      return {};
    }
  }

  Future<int> _getCompletedJobsCount(String userId) async {
    try {
      final user = await Supabase.instance.client
          .from('users')
          .select('jobs_accepted_count')
          .eq('id', userId)
          .single();
      return user['jobs_accepted_count'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _getInProgressJobsCount(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('jobs')
          .select('*')
          .eq('assigned_business_id', userId)
          .eq('status', 'in_progress')
          .count(CountOption.exact);
      return response.count;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _getNewOrdersCount(String userId) async {
    try {
      return await _market.countListings(
        status: 'all',
        excludePostedBy: userId,
      );
    } catch (_) {
      return 0;
    }
  }

  Future<int> _getMyBidsCount(String userId) async {
    try {
      final api = ApiService();
      final response = await api.get(
        '/market/bids?bidderId=$userId&statuses=pending,selected,awaiting_confirmation',
      );
      
      if (response['success'] == true) {
        final bids = List<Map<String, dynamic>>.from(response['data'] ?? []);
        
        final uniqueListingIds = bids
            .map((b) => b['listing_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .toSet();
            
        if (uniqueListingIds.isNotEmpty) {
          final listings = await Supabase.instance.client
              .from('marketplace_listings')
              .select('id, status')
              .inFilter('id', uniqueListingIds.toList());
              
          final activeListings = listings.where((l) {
            final status = l['status']?.toString();
            return status == 'open' || status == 'created';
          }).length;
          
          return activeListings;
        }
            
        return 0;
      } else {
        return await _getMyBidsCountFallback(userId);
      }
    } catch (e) {
      print('❌ [_getMyBidsCount] 에러: $e');
      return await _getMyBidsCountFallback(userId);
    }
  }

  Future<int> _getMyBidsCountFallback(String userId) async {
    try {
      final bids = await Supabase.instance.client
          .from('order_bids')
          .select('listing_id, status')
          .eq('bidder_id', userId);
          
      final uniqueIds = <String>{};
      for (final bid in bids) {
        final status = bid['status']?.toString() ?? '';
        if (status == 'pending') {
          final listingId = bid['listing_id']?.toString();
          if (listingId != null) uniqueIds.add(listingId);
        }
      }
      
      if (uniqueIds.isEmpty) return 0;
      
      final listings = await Supabase.instance.client
          .from('marketplace_listings')
          .select('id, status')
          .inFilter('id', uniqueIds.toList());
          
      final activeListings = listings.where((l) {
        final status = l['status']?.toString();
        return status == 'open' || status == 'created';
      }).length;
      
      return activeListings;
    } catch (_) {
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
            Icons.check_circle_outline,
            const Color(0xFF10B981),
            '+12%',
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
            Icons.hourglass_empty,
            const Color(0xFFF59E0B),
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
            '입찰 대기',
            data['myBids'] ?? 0,
            Icons.timer_outlined,
            const Color(0xFF3B82F6),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (trend != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  trend,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF10B981),
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
        const Text(
          '주요 메뉴',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E3A8A),
          ),
        ),
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
    return FutureBuilder<List<Ad>>(
      future: _adFuture,
      builder: (context, snapshot) {
        // 광고 데이터가 없어도 더미 데이터를 넣어서 슬라이드 기능 확인 (테스트용)
        final ads = (snapshot.hasData && snapshot.data!.isNotEmpty) 
            ? snapshot.data! 
            : [
                Ad(id: '1', title: '광고 1: 올수리 프리미엄', imageUrl: '', linkUrl: 'https://allsuri.app', location: 'dashboard_banner'),
                Ad(id: '2', title: '광고 2: 여름철 에어컨 점검', imageUrl: '', linkUrl: 'https://google.com', location: 'dashboard_banner'),
                Ad(id: '3', title: '광고 3: 장마철 누수 대비', imageUrl: '', linkUrl: '', location: 'dashboard_banner'),
              ];

        return SizedBox(
          height: 80,
          child: _DashboardAdCarousel(ads: ads),
        );
      },
    );
  }

}

class _DashboardAdCarousel extends StatefulWidget {
  final List<Ad> ads;
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

  Future<void> _launchUrl(String urlString) async {
    try {
      if (urlString.isEmpty) return;
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
                onTap: () => _launchUrl(ad.linkUrl ?? ''),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Text(
                      ad.title ?? '광고 ${index + 1}',
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

