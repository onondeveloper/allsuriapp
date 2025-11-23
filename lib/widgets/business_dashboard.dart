import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/business/estimate_requests_screen.dart';
import '../screens/business/estimate_management_screen.dart';
import '../screens/business/transfer_estimate_screen.dart';
import '../screens/notification/notification_screen.dart';
import '../screens/business/job_management_screen.dart';
import '../screens/business/order_marketplace_screen.dart';
import '../screens/business/my_order_management_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../screens/home/home_screen.dart';
import '../widgets/bottom_navigation.dart';
import 'interactive_card.dart';
import 'package:lottie/lottie.dart';
import 'package:allsuriapp/services/marketplace_service.dart';
import '../services/order_service.dart';
import '../screens/community/community_board_screen.dart';
import '../screens/labs/ai_assistant_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessDashboard extends StatefulWidget {
  const BusinessDashboard({Key? key}) : super(key: key);

  @override
  State<BusinessDashboard> createState() => _BusinessDashboardState();
}

class _BusinessDashboardState extends State<BusinessDashboard> {
  int _currentIndex = 0;
  final MarketplaceService _market = MarketplaceService();
  late Future<int> _callOpenCountFuture;
  late Future<int> _estimateRequestsCountFuture;
  late Future<int> _totalWaitingFuture;
  late Future<int> _myOrdersCountFuture;
  late Future<int> _myBidsCountFuture;
  
  RealtimeChannel? _marketplaceChannel;
  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
    // Futures are initialized in didChangeDependencies to safely read providers
  }

  void _setupRealtimeListeners() {
    // marketplace_listings 변경 감시
    _marketplaceChannel = Supabase.instance.client
        .channel('public:marketplace_listings')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'marketplace_listings',
          callback: (payload) {
            print('🔄 [marketplace_listings] 변경 감지');
            if (mounted) {
              _refreshCounts();
            }
          },
        )
        .subscribe();

    // orders (고객 견적) 변경 감시
    _ordersChannel = Supabase.instance.client
        .channel('public:orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            print('🔄 [orders] 변경 감지');
            if (mounted) {
              _refreshCounts();
            }
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
    _refreshCounts();
  }

  void _refreshCounts() {
    setState(() {
      _callOpenCountFuture = _getCallOpenCount();
      _estimateRequestsCountFuture = _getEstimateRequestsCount();
      _totalWaitingFuture = _getTotalWaitingCount();
      _myOrdersCountFuture = _getMyOrdersCount();
      _myBidsCountFuture = _getMyBidsCount();
    });
  }

  Future<int> _getCallOpenCount() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;
      
      // 오더 마켓에서 화면에 보이는 기준: open + withdrawn + created (자신이 올린 오더 제외)
      final items = await _market.listListings(status: 'all');
      final count = items.where((row) {
        final s = (row['status'] ?? '').toString();
        final postedBy = row['posted_by']?.toString() ?? '';
        final isValidStatus = s == 'open' || s == 'withdrawn' || s == 'created';
        final isNotMyOrder = postedBy != currentUserId;
        return isValidStatus && isNotMyOrder;
      }).length;
      print('🔍 [_getCallOpenCount] 오더 개수 (자신 제외): $count');
      return count;
    } catch (e) {
      print('❌ [_getCallOpenCount] 에러: $e');
      return 0;
    }
  }

  Future<int> _getEstimateRequestsCount() async {
    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      final all = await orderService.getOrders();
      final available = all.where((o) => o.status == 'pending' && !o.isAwarded).length;
      print('🔍 [_getEstimateRequestsCount] 고객 견적 요청 개수: $available');
      return available;
    } catch (e) {
      print('❌ [_getEstimateRequestsCount] 에러: $e');
      return 0;
    }
  }

  Future<int> _getTotalWaitingCount() async {
    try {
      final results = await Future.wait<int>([
        _getCallOpenCount(),
        _getEstimateRequestsCount(),
      ]);
      final total = results.fold<int>(0, (sum, v) => sum + v);
      print('🔍 [_getTotalWaitingCount] 총 공사 개수: $total');
      return total;
    } catch (e) {
      print('❌ [_getTotalWaitingCount] 에러: $e');
      return 0;
    }
  }

  Future<int> _getMyOrdersCount() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;
      
      if (currentUserId == null) return 0;
      
      // 내가 만든 오더 수
      final items = await _market.listListings(status: 'all');
      final count = items.where((row) {
        final postedBy = row['posted_by']?.toString() ?? '';
        return postedBy == currentUserId;
      }).length;
      print('🔍 [_getMyOrdersCount] 내가 만든 오더 수: $count');
      return count;
    } catch (e) {
      print('❌ [_getMyOrdersCount] 에러: $e');
      return 0;
    }
  }

  Future<int> _getMyBidsCount() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;
      
      if (currentUserId == null) return 0;
      
      // 내가 입찰한 오더 수
      final bids = await _market.getBidsByBidder(currentUserId);
      final activeBids = bids.where((bid) {
        final status = bid['status']?.toString() ?? '';
        return status != 'withdrawn'; // 취소하지 않은 입찰만
      }).length;
      print('🔍 [_getMyBidsCount] 입찰한 오더 수: $activeBids');
      return activeBids;
    } catch (e) {
      print('❌ [_getMyBidsCount] 에러: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.currentUser;
        final businessName = (user?.businessName != null && user!.businessName!.trim().isNotEmpty)
            ? user.businessName!
            : (user?.name ?? "사업자");
        
        return WillPopScope(
          onWillPop: () async {
            // 사업자는 홈이 곧 대시보드이므로 남겨둠 (스택 클리어 없이 true 반환 시 기본 pop)
            return false; // 기본 뒤로가기 방지 (홈으로 나가는 것을 방지)
          },
          child: Scaffold(
          appBar: AppBar(
            title: Text('올수리에서 번창하세요!'),
            centerTitle: true,
            actions: [
              FutureBuilder<int>(
                future: NotificationService().getUnreadCount(user?.id ?? ''),
                builder: (context, snapshot) {
                  final unread = snapshot.data ?? 0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationScreen()),
                          );
                        },
                        tooltip: '알림',
                      ),
                      if (unread > 0)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 26,
                                height: 26,
                                child: Lottie.asset(
                                  'assets/lottie/notification_bell.json',
                                  repeat: false,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  unread.toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modern welcome banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.12),
                        Theme.of(context).colorScheme.secondary.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FutureBuilder<int>(
                          future: _totalWaitingFuture,
                          builder: (context, snapshot) {
                            final n = snapshot.data ?? 0;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$n',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$businessName 님,',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<List<int>>(
                              future: Future.wait([
                                _callOpenCountFuture,
                                _myOrdersCountFuture,
                                _myBidsCountFuture,
                              ]),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  );
                                }
                                
                                final newOrders = snapshot.data![0];
                                final myOrders = snapshot.data![1];
                                final myBids = snapshot.data![2];
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildStatRow(
                                      context,
                                      '새로운 오더',
                                      newOrders,
                                      Colors.orange,
                                    ),
                                    const SizedBox(height: 2),
                                    _buildStatRow(
                                      context,
                                      '내가 만든 오더',
                                      myOrders,
                                      Colors.blue,
                                    ),
                                    const SizedBox(height: 2),
                                    _buildStatRow(
                                      context,
                                      '입찰한 오더',
                                      myBids,
                                      Colors.green,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Menu grid (card-based) - Clean pastel design like reference image
                LayoutBuilder(
                  builder: (context, constraints) {
                    // 화면 너비에 따라 열 개수 동적 조정
                    final width = constraints.maxWidth;
                    final isLandscape = width > 600;
                    final crossAxisCount = isLandscape ? 3 : 2;
                    
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.95,
                      children: [
                    // 1) 오더
                   _buildCleanMenuCard(
                      context,
                      '오더',
                      Icons.handyman_outlined,
                      const Color(0xFFFFF3E0), // Light orange
                      const Color(0xFFF57C00), // Orange for icon
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OrderMarketplaceScreen(showSuccessMessage: false)),
                        );
                        if (!mounted) return;
                        _refreshCounts();
                      },
                      badgeFuture: _callOpenCountFuture,
                    ),
                    // 2) 내 공사
                    _buildCleanMenuCard(
                      context,
                      '내 공사',
                      Icons.construction_outlined,
                      const Color(0xFFFFF9C4), // Light yellow
                      const Color(0xFFF9A825), // Yellow for icon
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const JobManagementScreen()));
                      },
                    ),
                    // 3) 커뮤니티
                    _buildCleanMenuCard(
                      context,
                      '커뮤니티',
                      Icons.people_outline_rounded,
                      const Color(0xFFF3E5F5), // Light purple
                      const Color(0xFF7B1FA2), // Purple for icon
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CommunityBoardScreen()));
                      },
                    ),
                    // 4) 내 오더 관리 (내가 생성한 오더만 표시)
                    _buildCleanMenuCard(
                      context,
                      '내 오더 관리',
                      Icons.folder_open_outlined,
                      const Color(0xFFFCE4EC), // Light pink
                      const Color(0xFFC2185B), // Pink for icon
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const MyOrderManagementScreen()));
                      },
                    ),
                    /*
                    // 5) 고객 견적 (Disabled)
                    _buildCleanMenuCard(
                      context,
                      '고객 견적',
                      Icons.description_outlined,
                      const Color(0xFFE3F2FD), // Light blue
                      const Color(0xFF1976D2), // Blue for icon
                      null, // Disabled
                      badgeFuture: _estimateRequestsCountFuture,
                      isDisabled: true,
                    ),
                    // 6) AI 도우미 (Disabled)
                    _buildCleanMenuCard(
                      context,
                      'AI 도우미',
                      Icons.lightbulb_outline_rounded,
                      const Color(0xFFE8F5E9), // Light green
                      const Color(0xFF388E3C), // Green for icon
                      null, // Disabled
                      isDisabled: true,
                    ),
                    */
                      ],
                    );
                  },
                ),

                // 광고 공간
                const SizedBox(height: 24),
                _buildAdBanner(context),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigation(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        ));
      },
    );
  }

  Widget _buildCleanMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color backgroundColor,
    Color iconColor,
    VoidCallback? onTap, {
    Future<int>? badgeFuture,
    bool isDisabled = false,
  }) {
    return CleanMenuCard(
      title: title,
      icon: icon,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      onTap: onTap,
      badgeFuture: badgeFuture,
      isDisabled: isDisabled,
    );
  }

  Widget _buildAdBanner(BuildContext context) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // 광고 내용 (추후 WebView로 교체)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 36, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    '광고 공간',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // 터치 가능한 영역
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // TODO: 광고 클릭 시 WebView로 이동
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('광고 준비 중입니다')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count건',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// Clean, minimal menu card inspired by reference image
class CleanMenuCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;
  final Future<int>? badgeFuture;
  final bool isDisabled;

  const CleanMenuCard({
    super.key,
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
    this.badgeFuture,
    this.isDisabled = false,
  });

  @override
  State<CleanMenuCard> createState() => _CleanMenuCardState();
}

class _CleanMenuCardState extends State<CleanMenuCard> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
    if (v) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isDisabled ? null : (_) => _setPressed(true),
      onTapCancel: widget.isDisabled ? null : () => _setPressed(false),
      onTapUp: widget.isDisabled ? null : (_) {
        _setPressed(false);
        widget.onTap?.call();
      },
      child: Opacity(
        opacity: widget.isDisabled ? 0.5 : 1.0,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          child: Stack(
            children: [
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon with subtle background
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 44,
                        color: widget.iconColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge (알림 개수)
              if (widget.badgeFuture != null)
                Positioned(
                  right: 10,
                  top: 10,
                  child: FutureBuilder<int>(
                    future: widget.badgeFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5252),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
