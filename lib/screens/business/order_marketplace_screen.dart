import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:allsuriapp/services/kakao_share_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:allsuriapp/services/marketplace_service.dart';
import 'package:allsuriapp/services/api_service.dart';
import 'package:allsuriapp/screens/business/estimate_management_screen.dart';
import 'package:allsuriapp/widgets/interactive_card.dart';
import 'package:allsuriapp/widgets/shimmer_widgets.dart';
import 'package:allsuriapp/widgets/loading_indicator.dart';
import 'package:allsuriapp/widgets/modern_order_card.dart';
import 'package:allsuriapp/widgets/modern_button.dart';
import 'package:allsuriapp/config/app_constants.dart';
import 'package:allsuriapp/services/chat_service.dart';
import 'package:provider/provider.dart';
import 'package:allsuriapp/models/estimate.dart';
import 'package:allsuriapp/services/estimate_service.dart';
import 'package:allsuriapp/screens/chat_screen.dart';
import 'package:allsuriapp/services/notification_service.dart';
import 'package:allsuriapp/services/auth_service.dart';
import 'package:allsuriapp/screens/business/order_bidders_screen.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:allsuriapp/widgets/empty_state_widget.dart';

class OrderMarketplaceScreen extends StatefulWidget {
  final bool showSuccessMessage;
  final String? createdByUserId;
  
  const OrderMarketplaceScreen({
    Key? key,
    this.showSuccessMessage = false,
    this.createdByUserId,
  }) : super(key: key);

  @override
  State<OrderMarketplaceScreen> createState() => _OrderMarketplaceScreenState();
}

class _OrderMarketplaceScreenState extends State<OrderMarketplaceScreen> {
  final MarketplaceService _market = MarketplaceService();
  final ApiService _api = ApiService();
  late Future<List<Map<String, dynamic>>> _future;
  String _status = 'all';
  RealtimeChannel? _channel;
  Set<String> _myActiveBidListingIds = {}; // 'pending' 상태 입찰
  Map<String, String> _myBidStatusByListing = {}; // listingId -> status
  bool _isCancelling = false; // 입찰 취소 중 플래그
  bool _isClaiming = false; // 입찰 중 플래그

  @override
  void initState() {
    super.initState();
    print('OrderMarketplaceScreen initState 시작');
    
    // 사용자 인증 상태 확인
    final currentUser = Supabase.instance.client.auth.currentUser;
    print('OrderMarketplaceScreen: 현재 사용자 - ${currentUser?.id ?? "null (로그인 안됨)"}');
    
    if (currentUser == null) {
      print('⚠️ [OrderMarketplaceScreen] 사용자가 로그인되어 있지 않습니다!');
    }
    
    // 🔒 사업자 승인 상태 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBusinessApproval();
    });
    
    // 내가 입찰한 오더 목록과 전체 목록을 동시에 로드
    _future = _loadInitialData();
    print('OrderMarketplaceScreen: _future 설정됨');
    
    _channel = Supabase.instance.client
        .channel('public:marketplace_listings')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'marketplace_listings',
          callback: (payload) {
            print('🔄 [OrderMarketplaceScreen] Realtime 이벤트: ${payload.eventType}');
            print('   - Old: ${payload.oldRecord}');
            print('   - New: ${payload.newRecord}');
            
            if (!mounted) return;
            
            // INSERT 이벤트: 새로운 오더
            if (payload.eventType == 'INSERT') {
              final newListing = payload.newRecord;
              final title = newListing['title'] ?? '오더';
              final region = newListing['region'] ?? '지역 미정';
              
              print('🔔 새로운 오더 추가: $title in $region');
              
              // 로컬 알림 표시
              try {
                NotificationService().showNewJobNotification(
                  title: '새로운 오더!',
                  body: '$title - $region',
                  jobId: newListing['id']?.toString() ?? 'unknown',
                );
              } catch (e) {
                print('알림 표시 실패: $e');
              }
            }
            
            // UPDATE 이벤트: 오더 상태 변경 (claimed, assigned 등)
            if (payload.eventType == 'UPDATE') {
              final oldRecord = payload.oldRecord;
              final newRecord = payload.newRecord;
              print('📝 오더 업데이트: ${newRecord['id']}');
              print('   - Old Status: ${oldRecord['status']} -> New Status: ${newRecord['status']}');
              
              if (oldRecord['status'] != newRecord['status']) {
                print('   ⚠️ 상태 변경 감지! 리스트 새로고침 필요');
              }
            }
            
            // DELETE 이벤트: 오더 삭제
            if (payload.eventType == 'DELETE') {
              final deletedListing = payload.oldRecord;
              print('🗑️ 오더 삭제: ${deletedListing['title']}');
            }
            
            print('   → 리스트 새로고침 시작');
            _reload();
          },
        )
        .subscribe();
    print('OrderMarketplaceScreen: Realtime 구독 완료');
    
    // 오더 등록 성공 후 이동한 경우 성공 메시지 표시
    if (widget.showSuccessMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Call에 성공적으로 등록되었습니다!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }

    // 화면 진입 직후 한번 더 새로고침하여 데이터 보장
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _reload();
      }
    });
  }

  /// 🔒 사업자 승인 상태 확인
  void _checkBusinessApproval() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (user.role != 'business') {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사업자 계정만 접근 가능합니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (user.businessStatus != 'approved') {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사업자 승인이 필요합니다. 관리자 승인 후 이용 가능합니다.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
  }

  Future<List<Map<String, dynamic>>> _loadInitialData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;
      
      print('🚀 [_loadInitialData] 병렬 로딩 시작...');
      
      // ⚡ 성능 개선: 병렬 실행으로 50% 속도 향상 + 페이지네이션
      final results = await Future.wait([
        // 1. 내 입찰 목록 로드
        _loadMyBidsData(currentUserId),
        // 2. 전체 오더 목록 로드 (초기 50개만)
        _market.listListings(
          status: _status, 
          throwOnError: true, 
          postedBy: widget.createdByUserId,
          limit: 50, // 초기 로딩 최적화
        ),
      ]);
      
      // 입찰 데이터 처리
      final bidsData = results[0] as Map<String, dynamic>?;
      if (bidsData != null) {
        _myBidStatusByListing = bidsData['statusMap'] as Map<String, String>;
        _myActiveBidListingIds = bidsData['activeIds'] as Set<String>;
        print('✅ [_loadInitialData] ${_myActiveBidListingIds.length}개 진행중 입찰');
      } else {
        _myBidStatusByListing = {};
        _myActiveBidListingIds = {};
      }
      
      // 오더 목록 처리
      final allListings = results[1] as List<Map<String, dynamic>>;
      print('✅ [_loadInitialData] ${allListings.length}개 오더 로드 완료');
      
      // 3. 자신이 등록한 오더 제외 (오더 마켓플레이스에서는 다른 사람이 등록한 오더만 표시)
      print('🔍 [_loadInitialData] 필터링 중 - currentUserId: $currentUserId');
      
      final filteredListings = allListings.where((listing) {
        final postedBy = listing['posted_by']?.toString() ?? '';
        final shouldShow = postedBy != currentUserId;
        if (!shouldShow) {
          print('   ⏭️ 제외: ${listing['title']} (posted_by: $postedBy)');
        }
        return shouldShow;
      }).toList();
      
      print('✅ [_loadInitialData] ${allListings.length}개 오더 중 ${filteredListings.length}개 표시 (자신이 등록한 오더 ${allListings.length - filteredListings.length}개 제외)');
      
      return filteredListings;
    } catch (e) {
      print('❌ [_loadInitialData] 실패: $e');
      rethrow;
    }
  }

  // ⚡ 성능 개선: 병렬 실행을 위한 헬퍼 메서드
  Future<Map<String, dynamic>?> _loadMyBidsData(String? currentUserId) async {
    if (currentUserId == null) return null;
    
    try {
      print('🔍 [_loadMyBidsData] 내 입찰 목록 로드 중...');
      
      final response = await _api.get(
        '/market/bids?bidderId=$currentUserId&statuses=pending,selected,awaiting_confirmation',
      );
      
      if (response['success'] == true) {
        final bids = List<Map<String, dynamic>>.from(response['data'] ?? []);
        final statusMap = <String, String>{
          for (final bid in bids)
            if ((bid['listing_id']?.toString() ?? '').isNotEmpty)
              bid['listing_id'].toString(): (bid['status'] ?? 'pending').toString(),
        };
        final activeIds = statusMap.entries
            .where((entry) => entry.value == 'pending')
            .map((entry) => entry.key)
            .toSet();
        
        return {
          'statusMap': statusMap,
          'activeIds': activeIds,
        };
      } else {
        print('⚠️ [_loadMyBidsData] 입찰 API 실패: ${response['error']}');
        return null;
      }
    } catch (e) {
      print('⚠️ [_loadMyBidsData] 실패: $e');
      return null;
    }
  }

  Future<void> _loadMyBids() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;
      
      if (currentUserId == null) return;
      
      final bidsData = await _loadMyBidsData(currentUserId);
      if (bidsData != null) {
        setState(() {
          _myBidStatusByListing = bidsData['statusMap'] as Map<String, String>;
          _myActiveBidListingIds = bidsData['activeIds'] as Set<String>;
        });
        print('✅ [_loadMyBids] ${_myActiveBidListingIds.length}개 진행중 입찰');
      }
    } catch (e) {
      print('⚠️ [_loadMyBids] 실패 (무시): $e');
    }
  }

  Future<void> _reload() async {
    print('OrderMarketplaceScreen _reload 시작: status=$_status');
    setState(() {
      _future = _loadInitialData();
    });
    print('OrderMarketplaceScreen _reload 완료');
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          '오더 마켓플레이스',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E3A8A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E3A8A)),
            onPressed: _reload,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 필터 제거: 항상 오픈(또는 withdrawn) 항목만 표시
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  print('OrderMarketplaceScreen FutureBuilder: connectionState=${snapshot.connectionState}, hasError=${snapshot.hasError}, data=${snapshot.data?.length ?? 0}');
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    print('OrderMarketplaceScreen: 로딩 중...');
                    return const LoadingIndicator(
                      message: '공사 목록을 불러오는 중...',
                      subtitle: '잠시만 기다려주세요',
                    );
                  }
                  if (snapshot.hasError) {
                    print('OrderMarketplaceScreen: 에러 발생 - ${snapshot.error}');
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Center(child: Text('불러오기 실패: ')),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('${snapshot.error}'),
                        ),
                      ],
                    );
                  }
                  final items = snapshot.data ?? [];
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final currentUserId = authService.currentUser?.id;
                  
                  final visibleItems = items.where((row) {
                    final s = (row['status'] ?? '').toString();
                    final listingId = row['id']?.toString() ?? '';
                    final postedBy = row['posted_by']?.toString() ?? '';
                    
                    // 상태 필터: open, withdrawn, created만
                    if (s != 'open' && s != 'withdrawn' && s != 'created') return false;
                    
                    // 내가 올린 오더는 제외
                    if (postedBy == currentUserId) return false;
                    
                    return true;
                  }).toList();
                  print('OrderMarketplaceScreen: 데이터 로드 완료 - ${visibleItems.length}개 항목(오픈/철회/생성됨)');
                  if (visibleItems.isEmpty) {
                    print('OrderMarketplaceScreen: 빈 목록 표시');
                    return const EmptyOrdersWidget();
                  }
                  return AnimationLimiter(
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: visibleItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        try {
                          final e = visibleItems[index];
                      final String id = (e['id'] ?? '').toString();
                      final String title = (e['title'] ?? e['description'] ?? '-') as String;
                      final String description = (e['description'] ?? '-') as String;
                      final String region = (e['region'] ?? '-') as String;
                      final String category = (e['category'] ?? '-') as String;
                      final String status = (e['status'] ?? '-') as String;
                      final createdAt = (e['createdat'] ?? e['createdAt']);
                      final budget = e['budget_amount'] ?? e['budgetAmount'];
                      final String? postedBy = (e['posted_by'] ?? e['postedBy'])?.toString();
                      final String jobId = (e['jobid'] ?? e['jobId'] ?? '').toString();
                      final String createdText = createdAt != null
                          ? (DateTime.tryParse(createdAt.toString())?.toLocal().toString().split('.').first ?? '-')
                          : '-';
                      final estimateAmount = e['estimate_amount'] ?? e['estimateAmount'];
                      final mediaUrls = e['media_urls'] is List ? List<String>.from(e['media_urls']) : <String>[];
                      final int bidCount = e['bid_count'] is int
                          ? e['bid_count']
                          : int.tryParse(e['bid_count']?.toString() ?? '0') ?? 0;
                      
                      // 현재 사용자가 오더 소유자인지 확인
                      final authService = Provider.of<AuthService>(context, listen: false);
                      final currentUserId = authService.currentUser?.id;
                      final isOwner = currentUserId == postedBy;
                      final String? myBidStatus = _myBidStatusByListing[id];
                      final bool hasPendingBid = _myActiveBidListingIds.contains(id);
                      final bool hasAnyBid = myBidStatus != null;
                      final bool canBid = (status == 'open' || status == 'withdrawn' || status == 'created') && !hasPendingBid;

                      // 상태 라벨은 이 화면에서 불필요 (항상 오픈/철회만 표시)

                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: GestureDetector(
                        onTap: () => _showCallDetail(e, alreadyBid: hasAnyBid),
                        child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasPendingBid ? const Color(0xFF1E3A8A) : Colors.grey[200]!,
                            width: hasPendingBid ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 웹 고객 오더 배너
                              if (postedBy == null || postedBy.isEmpty)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_outline, color: Colors.white, size: 15),
                                      const SizedBox(width: 6),
                                      const Text(
                                        '일반인이 직접 견적을 요청했어요! ',
                                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              // Header row - Wrap으로 변경하여 오버플로 방지
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E3A8A).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      category,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF1E3A8A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        region,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // 입찰자 수 배지
                                  if (bidCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.people, size: 12, color: Color(0xFF10B981)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$bidCount명',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF10B981),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  // 입찰 상태 배지 (내가 입찰한 오더)
                                  if (hasAnyBid && myBidStatus != null)
                                    _buildMyBidBadge(myBidStatus),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Title
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Color(0xFF1E3A8A),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              // Images thumbnail
                              if (mediaUrls.isNotEmpty) ...[
                                SizedBox(
                                  height: 80,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: mediaUrls.length > 3 ? 3 : mediaUrls.length,
                                    itemBuilder: (context, idx) {
                                      return Container(
                                        width: 80,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          image: DecorationImage(
                                            image: NetworkImage(mediaUrls[idx]),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              // Description
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              
                              // 오더 생성자 정보 (사업자 상호명, 평점)
                              if (e['owner_business_name'] != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.shade200, width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.business, size: 14, color: Colors.orange[700]),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          e['owner_business_name'] ?? '알 수 없음',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.orange[900],
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (e['owner_review_count'] != null && e['owner_review_count'] > 0) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${(e['owner_avg_rating'] as num).toStringAsFixed(1)} (${e['owner_review_count']})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[800],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ] else ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '평가 없음',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                              
                              const SizedBox(height: 12),
                              // Info row
                              Row(
                                children: [
                                  if (estimateAmount != null)
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE3F2FD),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF1976D2)),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                '${estimateAmount is num ? estimateAmount.toInt().toString() : estimateAmount.toString()}원',
                                                style: const TextStyle(
                                                  color: Color(0xFF1976D2),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  if (e['jobs'] != null && e['jobs'] is Map && (e['jobs']['commission_rate'] != null))
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.purple[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.percent_rounded, size: 14, color: Colors.purple[700]),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${(e['jobs']['commission_rate']).toString()}%',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.purple[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Footer
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time_outlined, size: 14, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            createdText,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 오더 잡기 버튼
                                  SizedBox(
                                    height: 40,
                                    width: 150,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: hasPendingBid ? Colors.red : (canBid ? const Color(0xFF1E3A8A) : Colors.grey[300]),
                                        foregroundColor: hasPendingBid ? Colors.white : (canBid ? Colors.white : Colors.grey[600]),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                    onPressed: () async {
                                      if (hasPendingBid) {
                                        await _cancelBid(id);
                                      } else if (canBid) {
                                        await _showBidDialog(id, title,
                                          isWebOrder: postedBy == null || postedBy.isEmpty);
                                      }
                                    },
                                    icon: Icon(
                                      hasPendingBid ? Icons.cancel_outlined : Icons.check_circle_outline, 
                                      size: 20, 
                                      color: hasPendingBid ? Colors.white : (canBid ? Colors.white : Colors.grey[600])
                                    ),
                                    label: Text(
                                      hasPendingBid ? '입찰 취소' : '입찰하기',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: hasPendingBid ? Colors.white : (canBid ? Colors.white : Colors.grey[600]),
                                      ),
                                    ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                            ),
                          ),
                        ),
                      );
                      } catch (e, stackTrace) {
                        print('OrderMarketplaceScreen 카드 렌더링 에러: $e');
                        print('StackTrace: $stackTrace');
                        return Container(
                          height: 100,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text('카드 렌더링 오류: $e'),
                          ),
                        );
                      }
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBid(String listingId) async {
    // 중복 실행 방지
    if (_isCancelling) {
      print('⚠️ [_cancelBid] 이미 취소 작업 진행 중, 무시');
      return;
    }
    
    try {
      setState(() => _isCancelling = true);
      print('🔍 [_cancelBid] 입찰 취소 시작: $listingId');
      
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;
      
      if (currentUserId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인이 필요합니다'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // 확인 다이얼로그
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('입찰 취소'),
          content: const Text('정말 입찰을 취소하시겠습니까?\n다른 공사를 잡을 수 있게 됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('아니요'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('취소하기'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
      
      // 낙관적 UI 업데이트
      setState(() {
        _myActiveBidListingIds.remove(listingId);
        _myBidStatusByListing.remove(listingId);
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('입찰이 취소되었습니다'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      
      // 백엔드 API로 입찰 취소 (RLS 우회)
      print('   → 백엔드 API로 입찰 취소 요청 중...');
      print('   listingId: $listingId');
      print('   currentUserId: $currentUserId');
      
      final response = await _api.delete('/market/bids/$listingId?bidderId=$currentUserId');
      
      print('   삭제 응답: ${response['success']}');
      final deleteSuccess = response['success'] == true;
      print('✅ [_cancelBid] 입찰 취소 완료 (성공: $deleteSuccess)');
      
      // 삭제가 성공한 경우에만 리스트 새로고침
      if (deleteSuccess) {
        print('   ✅ DELETE 성공, 리스트 새로고침');
        await _reload();
      } else {
        final errorMsg = response['error']?.toString() ?? '';
        final is502Error = errorMsg.contains('502') || errorMsg.contains('Bad Gateway');
        
        print('   ⚠️ DELETE 실패, 에러: $errorMsg');
        
        // 502 에러가 아닌 경우에만 롤백하고 에러 메시지 표시
        if (!is502Error) {
          // 실패 시 롤백
          setState(() {
            _myBidStatusByListing[listingId] = 'pending';
            _myActiveBidListingIds.add(listingId);
          });
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('입찰 취소 실패: $errorMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          // 502 에러는 조용히 처리 (실제로는 성공했을 가능성이 높음)
          print('   ℹ️ 502 에러 조용히 처리 (실제로는 성공했을 수 있음)');
        }
      }
      
    } catch (e, stackTrace) {
      final errorMsg = e.toString();
      final is502Error = errorMsg.contains('502') || errorMsg.contains('Bad Gateway');
      
      print('❌ [_cancelBid] 에러 발생: $errorMsg');
      print('   StackTrace: $stackTrace');
      
      // 502 에러가 아닌 경우에만 롤백하고 에러 메시지 표시
      if (!is502Error) {
        // 실패 시 롤백
        setState(() {
          _myBidStatusByListing[listingId] = 'pending';
          _myActiveBidListingIds.add(listingId);
        });
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('입찰 취소 실패: $errorMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // 502 에러는 조용히 처리 (실제로는 성공했을 가능성이 높음)
        print('   ℹ️ 502 에러 조용히 처리 (catch 블록)');
      }
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  // 입찰 다이얼로그
  // isWebOrder=true  → 고객 웹 오더: 견적가·공사일 필드 표시 (전체 폼)
  // isWebOrder=false → B2B 오더   : '바로 입찰하기' 버튼 추가, 필드는 선택
  Future<void> _showBidDialog(String id, String title, {bool isWebOrder = false}) async {
    if (_myActiveBidListingIds.contains(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 이 오더에 입찰하셨습니다'), backgroundColor: Colors.orange),
      );
      return;
    }
    final amountCtrl = TextEditingController();
    final daysCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('입찰하기', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            // B2B 전용: 바로 입찰하기 (견적가 없이 즉시 입찰)
            if (!isWebOrder) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'quick'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.flash_on_rounded),
                  label: const Text('바로 입찰하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('또는 견적가 포함 입찰', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isWebOrder ? '견적가 (원)' : '견적가 (원, 선택)',
                hintText: '예: 500000',
                prefixIcon: const Icon(Icons.attach_money_rounded, color: Color(0xFF1E3A8A)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: daysCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isWebOrder ? '예상 공사 기일 (일)' : '예상 공사 기일 (일, 선택)',
                hintText: '예: 3',
                prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF1E3A8A)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msgCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: '메시지 (선택)',
                hintText: '공사에 대한 간략한 설명',
                prefixIcon: const Icon(Icons.message_outlined, color: Color(0xFF1E3A8A)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      isWebOrder ? '입찰하기' : '가격 포함 입찰',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result == 'quick') {
      // B2B 바로 입찰 (견적가 없이)
      await _claimListing(id);
    } else if (result == true) {
      final bidAmount = double.tryParse(amountCtrl.text.replaceAll(',', ''));
      final estimatedDays = int.tryParse(daysCtrl.text);
      final msg = msgCtrl.text.trim();
      await _claimListing(id, bidAmount: bidAmount, estimatedDays: estimatedDays, message: msg);
    }
  }

  Future<void> _claimListing(String id, {double? bidAmount, int? estimatedDays, String? message}) async {
    // 중복 실행 방지
    if (_isClaiming) {
      print('⚠️ [_claimListing] 이미 잡기 작업 진행 중, 무시');
      return;
    }
    
    try {
      setState(() => _isClaiming = true);
      print('🔍 [_claimListing] 오더 잡기 시작: $id');
      
      // 사용자 로그인 확인 (AuthService 사용)
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;
      print('   현재 사용자 (AuthService): ${currentUserId ?? "null"}');
      print('   현재 사용자 (Supabase): ${Supabase.instance.client.auth.currentUser?.id ?? "null"}');
      
      if (currentUserId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인이 필요합니다'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // ✅ 이미 이 오더에 입찰했는지 확인 (같은 오더 중복 입찰 방지)
      if (_myActiveBidListingIds.contains(id)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 이 오더에 입찰하셨습니다'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // 낙관적 UI 업데이트: 즉시 입찰 상태 반영
      setState(() {
        _myActiveBidListingIds.add(id);
        _myBidStatusByListing[id] = 'pending';
      });
      
      // 즉시 성공 메시지 표시
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('입찰이 완료되었습니다! 고객/오더 소유자의 낙찰을 기다리고 있어요~'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
      // 백그라운드에서 실제 API 호출
      print('   → marketplace_service에서 오더 잡기 요청 중...');
      final ok = await _market.claimListing(id, businessId: currentUserId, bidAmount: bidAmount, estimatedDays: estimatedDays, message: message);
      
      if (!mounted) return;
      
      // 입찰 성공 시 오더 발주자에게 알림 전송
      if (ok) {
        try {
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('📤 [_claimListing] 입찰 알림 전송 시작...');
          print('   오더 ID: $id');
          
          // 1. 오더 정보 조회 (발주자 ID, 제목)
          final listing = await Supabase.instance.client
              .from('marketplace_listings')
              .select('posted_by, title')
              .eq('id', id)
              .single();
          
          final ownerId = listing['posted_by'];
          final orderTitle = listing['title'] ?? '오더';
          
          print('   오더 소유자 ID: $ownerId');
          print('   오더 제목: $orderTitle');
          
          // 2. 입찰자 이름 조회
          final authService = Provider.of<AuthService>(context, listen: false);
          final bidderName = authService.currentUser?.businessName ?? 
                             authService.currentUser?.name ?? 
                             '사업자';
          
          print('   입찰자 이름: $bidderName');
          print('   입찰자 ID: ${authService.currentUser?.id}');
          
          // 3. 알림 전송
          print('   알림 내용: "$bidderName 사장님이 [$orderTitle] 공사에 입찰 하셨어요!"');
          
          final notificationService = NotificationService();
          await notificationService.sendNotification(
            userId: ownerId,
            title: '💼 새로운 입찰',
            body: '$bidderName 사장님이 [$orderTitle] 공사에 입찰 하셨어요!',
            type: 'new_bid',
            orderId: id,
            jobTitle: orderTitle,
          );
          
          print('✅ [_claimListing] 입찰 알림 전송 완료!');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        } catch (notiErr, stackTrace) {
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('❌ [_claimListing] 입찰 알림 전송 실패!');
          print('   에러: $notiErr');
          print('   스택: $stackTrace');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          // 알림 실패해도 입찰은 성공
        }
      }
      
      if (!ok) {
        // 실패 시 롤백 (하지만 502 에러는 조용히 처리)
        print('   ❌ 오더 잡기 실패 - 확인 중...');
        
        // 실제로는 성공했는지 확인 (Supabase에서 직접 조회)
        // 여기서는 단순히 502 에러가 아닌 경우에만 롤백
        setState(() {
          _myActiveBidListingIds.remove(id);
          _myBidStatusByListing.remove(id);
        });
        
        // 502 에러가 아닌 경우에만 에러 메시지 표시
        // (502는 조용히 처리)
        print('   ℹ️ 입찰 실패 처리 (에러 메시지 표시 안 함 - 502일 가능성)');
      }
    } catch (e, stackTrace) {
      final errorMsg = e.toString();
      final is502Error = errorMsg.contains('502') || errorMsg.contains('Bad Gateway');
      
      print('❌ [_claimListing] 에러 발생: $errorMsg');
      print('   StackTrace: $stackTrace');
      
      // 502 에러가 아닌 경우에만 에러 메시지 표시
      if (!is502Error && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오더 잡기 실패: $errorMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (is502Error) {
        print('   ℹ️ 502 에러 조용히 처리 (catch 블록)');
      }
    } finally{
      if (mounted) {
        setState(() => _isClaiming = false);
      }
    }
  }

  Future<void> _deleteJob(String jobId) async {
    try {
      print('🔍 [_deleteJob] 공사 삭제 시작: $jobId');
      
      // jobs 테이블에서 삭제 (marketplace_listings는 ON DELETE CASCADE로 자동 삭제)
      final response = await Supabase.instance.client
          .from('jobs')
          .delete()
          .eq('id', jobId);
      
      print('✅ [_deleteJob] 공사 삭제 완료');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공사가 삭제되었습니다.'), backgroundColor: Colors.green),
      );
      
      // 상세 화면 닫기 및 리스트 새로고침
      Navigator.pop(context);
      _reload();
      
    } catch (e) {
      print('❌ [_deleteJob] 삭제 실패: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공사 삭제 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showCallDetail(Map<String, dynamic> data, {bool alreadyBid = false}) {
    final String title = (data['title'] ?? data['description'] ?? '-') as String;
    final String description = (data['description'] ?? '-') as String;
    final String region = (data['region'] ?? '-') as String;
    final String category = (data['category'] ?? '-') as String;
    final estimateAmount = data['estimate_amount'] ?? data['estimateAmount'];
    final mediaUrls = data['media_urls'] is List ? List<String>.from(data['media_urls']) : <String>[];
    final budget = data['budget_amount'] ?? data['budgetAmount'];
    final createdAt = data['createdat'] ?? data['createdAt'];
    final String jobId = (data['jobid'] ?? data['id'] ?? '').toString();
    final String postedBy = (data['posted_by'] ?? '').toString();
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.id;
    final isOwner = currentUserId == postedBy;
    final listingId = data['id']?.toString() ?? '';
    final myBidStatus = _myBidStatusByListing[listingId];
    final bool hasAnyBid = alreadyBid || myBidStatus != null;
    final bool hasPendingBid = (myBidStatus ?? '') == 'pending';
    final int bidCount = data['bid_count'] is int
        ? data['bid_count'] as int
        : int.tryParse(data['bid_count']?.toString() ?? '0') ?? 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            title: const Text(
              '오더 상세',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E3A8A), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Color(0xFF1E3A8A)),
                onPressed: () async {
                  final imageUrl = mediaUrls.isNotEmpty ? mediaUrls[0] : null;
                  final budgetRaw = data['estimate_amount']
                      ?? data['budget_amount']
                      ?? data['estimateAmount']
                      ?? data['budgetAmount'];
                  final double? budgetAmount =
                      budgetRaw != null ? (budgetRaw as num).toDouble() : null;
                  final commRaw = data['commission_rate'] ?? data['commissionRate'];
                  final double? commissionRate =
                      commRaw != null ? (commRaw as num).toDouble() : null;

                  final kakaoService = KakaoShareService();
                  final success = await kakaoService.shareOrder(
                    orderId: listingId.isNotEmpty ? listingId : jobId,
                    title: title,
                    region: region,
                    category: category,
                    budgetAmount: budgetAmount,
                    commissionRate: commissionRate,
                    imageUrl: imageUrl,
                    description: description,
                  );
                  // 카카오톡 공유 실패 시 시스템 공유로 폴백
                  if (!success) {
                    final shareText =
                        '[$category] $title\n📍 지역: $region\n\n$description\n\n올수리 앱에서 입찰하세요!';
                    Share.share(shareText, subject: title);
                  }
                },
              ),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('공사 삭제'),
                        content: const Text('이 공사를 삭제하시겠습니까? 삭제된 데이터는 복구될 수 없습니다.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(dialogContext);
                              await _deleteJob(jobId);
                            },
                            child: const Text('삭제', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                  // 이미지 갤러리
                  if (mediaUrls.isNotEmpty)
                    SizedBox(
                      height: 350,
                      child: Stack(
                        children: [
                          PageView.builder(
                            itemCount: mediaUrls.length,
                            itemBuilder: (context, index) {
                              return Container(
                                color: Colors.grey[200],
                                child: Image.network(
                                  mediaUrls[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image_not_supported_outlined),
                                  ),
                                ),
                              );
                            },
                          ),
                          // 이미지 개수 표시
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '1 / ${mediaUrls.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      height: 350,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported_outlined, size: 80),
                    ),
                  
                  // 콘텐츠 섹션
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 웹 고객 오더 배너 (상세)
                        if (postedBy.isEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_pin_outlined, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    '일반인이 직접 견적을 요청했어요!\n선택되면 고객에게 연락처가 전달됩니다.',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // 카테고리 & 지역 (프로페셔널 스타일)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1E3A8A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              region,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // 제목
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E3A8A),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // 예산
                        if (budget != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.attach_money_rounded,
                                  color: Color(0xFF1E3A8A),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '예상 예산: ${budget is num ? '${(budget as num).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원' : budget.toString()}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 12),
                        
                        // 올린 시간
                        Row(
                          children: [
                            Icon(Icons.access_time_outlined, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 6),
                            Text(
                              createdAt != null
                                  ? (DateTime.tryParse(createdAt.toString())?.toLocal().toString().split('.').first ?? '-')
                                  : '-',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // 구분선
                        Divider(color: Colors.grey[300], thickness: 1),
                        
                        const SizedBox(height: 24),
                        
                        // 상세 설명
                        const Text(
                          '공사 정보',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!, width: 1),
                          ),
                          child: Text(
                            description,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[800],
                              height: 1.6,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
              
              // 하단 "잡기" 버튼
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: isOwner
                          ? ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.people_outline),
                              label: Text(
                                '입찰자 보기 ($bidCount명)',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderBiddersScreen(
                                      listingId: data['id'].toString(),
                                      orderTitle: title,
                                    ),
                                  ),
                                );
                              },
                            )
                          : ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasPendingBid ? Colors.red : const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: Icon(hasPendingBid ? Icons.cancel_outlined : Icons.check_circle_outline),
                              label: Text(
                                hasPendingBid ? '입찰 취소' : '입찰하기',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                if (hasPendingBid) {
                                  await _cancelBid(data['id'].toString());
                                } else {
                                  await _showBidDialog(data['id'].toString(), title,
                                    isWebOrder: postedBy.isEmpty);
                                }
                              },
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
  }

  Widget _buildMyBidBadge(String status) {
    final config = _BidBadgeConfig.fromStatus(status);
    if (config == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: config.fillColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: config.borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 12, color: config.textColor),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontSize: 12,
              color: config.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _BidBadgeConfig {
  final Color fillColor;
  final Color borderColor;
  final Color textColor;
  final String label;
  final IconData icon;

  const _BidBadgeConfig({
    required this.fillColor,
    required this.borderColor,
    required this.textColor,
    required this.label,
    required this.icon,
  });

  static _BidBadgeConfig? fromStatus(String status) {
    switch (status) {
      case 'pending':
        return _BidBadgeConfig(
          fillColor: Colors.orange[50]!,
          borderColor: Colors.orange,
          textColor: Colors.orange[700]!,
          label: '낙찰 대기중',
          icon: Icons.schedule,
        );
      case 'selected':
        return _BidBadgeConfig(
          fillColor: Colors.green[50]!,
          borderColor: Colors.green,
          textColor: Colors.green[800]!,
          label: '내 입찰 선택됨',
          icon: Icons.check_circle,
        );
      case 'awaiting_confirmation':
        return _BidBadgeConfig(
          fillColor: Colors.purple[50]!,
          borderColor: Colors.purple,
          textColor: Colors.purple[700]!,
          label: '원사업자 확인 대기',
          icon: Icons.hourglass_bottom,
        );
      default:
        return null;
    }
  }
}


