import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/business/estimate_requests_screen.dart';
import '../screens/business/estimate_management_screen.dart';
import '../screens/business/transfer_estimate_screen.dart';
import '../screens/notification/notification_screen.dart';
import '../screens/business/job_management_screen.dart';
import '../screens/business/call_marketplace_screen.dart';
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

  @override
  void initState() {
    super.initState();
    // Futures are initialized in didChangeDependencies to safely read providers
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
    });
  }

  Future<int> _getCallOpenCount() async {
    try {
      // Call 마켓에서 화면에 보이는 기준과 동일하게: open + withdrawn 만 집계
      final items = await _market.listListings(status: 'all');
      final count = items.where((row) {
        final s = (row['status'] ?? '').toString();
        return s == 'open' || s == 'withdrawn';
      }).length;
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _getEstimateRequestsCount() async {
    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      final all = await orderService.getOrders();
      final available = all.where((o) => o.status == 'pending' && !o.isAwarded).length;
      return available;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _getTotalWaitingCount() async {
    try {
      final results = await Future.wait<int>([
        _getCallOpenCount(),
        _getEstimateRequestsCount(),
      ]);
      return results.fold<int>(0, (sum, v) => sum + v);
    } catch (_) {
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
                        child: FutureBuilder<int>(
                          future: _totalWaitingFuture,
                          builder: (context, snapshot) {
                            final n = snapshot.data ?? 0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$businessName 님,',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$n건의 공사가 사장님을 애타게 기다리고 있어요!',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            );
                          },
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
                    _buildCleanMenuCard(
                      context,
                      '고객 견적',
                      Icons.description_outlined,
                      const Color(0xFFE3F2FD), // Light blue
                      const Color(0xFF1976D2), // Blue for icon
                      () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (context) => const EstimateRequestsScreen()));
                        if (!mounted) return;
                        _refreshCounts();
                      },
                      badgeFuture: _estimateRequestsCountFuture,
                    ),
                   _buildCleanMenuCard(
                      context,
                      'Call 공사',
                      Icons.handyman_outlined,
                      const Color(0xFFFFF3E0), // Light orange
                      const Color(0xFFF57C00), // Orange for icon
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CallMarketplaceScreen(showSuccessMessage: false)),
                        );
                        if (!mounted) return;
                        _refreshCounts();
                      },
                      badgeFuture: _callOpenCountFuture,
                    ),
                    _buildCleanMenuCard(
                      context,
                      '견적 관리',
                      Icons.folder_open_outlined,
                      const Color(0xFFFCE4EC), // Light pink
                      const Color(0xFFC2185B), // Pink for icon
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const EstimateManagementScreen()));
                      },
                    ),
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
                    _buildCleanMenuCard(
                      context,
                      'AI 도우미',
                      Icons.lightbulb_outline_rounded,
                      const Color(0xFFE8F5E9), // Light green
                      const Color(0xFF388E3C), // Green for icon
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AiAssistantScreen()));
                      },
                    ),
                      ],
                    );
                  },
                ),

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
    VoidCallback onTap, {
    Future<int>? badgeFuture,
  }) {
    return CleanMenuCard(
      title: title,
      icon: icon,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      onTap: onTap,
      badgeFuture: badgeFuture,
    );
  }
}

// Clean, minimal menu card inspired by reference image
class CleanMenuCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;
  final Future<int>? badgeFuture;

  const CleanMenuCard({
    super.key,
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
    this.badgeFuture,
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
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap();
      },
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
    );
  }
}
