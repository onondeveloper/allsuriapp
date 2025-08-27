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
    _callOpenCountFuture = _getCallOpenCount();
    _estimateRequestsCountFuture = _getEstimateRequestsCount();
    _totalWaitingFuture = _getTotalWaitingCount();
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

                // Menu grid (card-based)
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildMenuCard(
                      context,
                      '고객 견적',
                      Icons.search,
                      Colors.indigo,
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const EstimateRequestsScreen()));
                      },
                    ),
                   _buildMenuCard(
                      context,
                      'Call 공사',
                      Icons.campaign_outlined,
                      Colors.deepPurple,
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CallMarketplaceScreen(showSuccessMessage: false)));
                      },
                    ),
                    _buildMenuCard(
                      context,
                      '견적 관리',
                      Icons.list_alt,
                      Colors.teal,
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const EstimateManagementScreen()));
                      },
                    ),
                    _buildMenuCard(
                      context,
                      '내가 만든 공사',
                      Icons.assignment_turned_in,
                      Colors.amber,
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const JobManagementScreen()));
                      },
                    ),
                  ],
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

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    Future<int>? badgeFuture;
    if (title == '고객 견적') {
      badgeFuture = _estimateRequestsCountFuture;
    } else if (title == 'Call 공사') {
      badgeFuture = _callOpenCountFuture;
    }
    return DashboardMenuCard(
      title: title,
      icon: icon,
      color: color,
      onTap: onTap,
      badgeFuture: badgeFuture,
    );
  }
}

class DashboardMenuCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Future<int>? badgeFuture;

  const DashboardMenuCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeFuture,
  });

  @override
  State<DashboardMenuCard> createState() => _DashboardMenuCardState();
}

class _DashboardMenuCardState extends State<DashboardMenuCard> {
  bool _pressed = false;
  bool _hover = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(18);
    final card = AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: borderRadius,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.6)),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : _hover
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _pressed ? 0.98 : 1.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.color.withOpacity(0.95),
                          widget.color.withOpacity(0.70),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.badgeFuture != null)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: FutureBuilder<int>(
                        future: widget.badgeFuture,
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          if (count <= 0) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              count > 99 ? '99+' : count.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: widget.onTap,
        child: card,
      ),
    );
  }
}
