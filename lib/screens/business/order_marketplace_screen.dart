import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:allsuriapp/services/marketplace_service.dart';
import 'package:allsuriapp/screens/business/estimate_management_screen.dart';
import 'package:allsuriapp/widgets/interactive_card.dart';
import 'package:allsuriapp/widgets/shimmer_widgets.dart';
import 'package:allsuriapp/services/chat_service.dart';
import 'package:provider/provider.dart';
import 'package:allsuriapp/models/estimate.dart';
import 'package:allsuriapp/services/estimate_service.dart';
import 'package:allsuriapp/screens/chat_screen.dart';
import 'package:allsuriapp/services/notification_service.dart';
import 'package:allsuriapp/services/auth_service.dart';
import 'package:allsuriapp/screens/business/order_bidders_screen.dart';

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
  late Future<List<Map<String, dynamic>>> _future;
  String _status = 'all';
  RealtimeChannel? _channel;
  Set<String> _myBidListingIds = {}; // 내가 이미 입찰한 오더 ID 목록

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
    
    _loadMyBids(); // 내가 입찰한 오더 목록 로드
    _future = _market.listListings(status: _status, throwOnError: true, postedBy: widget.createdByUserId);
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

  Future<void> _loadMyBids() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;
      
      if (currentUserId == null) return;
      
      print('🔍 [_loadMyBids] 내 입찰 목록 로드 중...');
      
      // 내가 입찰한 오더 목록 조회
      final response = await Supabase.instance.client
          .from('order_bids')
          .select('listing_id')
          .eq('bidder_id', currentUserId)
          .eq('status', 'pending'); // pending 상태인 입찰만
      
      setState(() {
        _myBidListingIds = response.map((e) => e['listing_id'].toString()).toSet();
      });
      
      print('✅ [_loadMyBids] ${_myBidListingIds.length}개 입찰 확인');
    } catch (e) {
      print('⚠️ [_loadMyBids] 실패 (무시): $e');
    }
  }

  Future<void> _reload() async {
    print('OrderMarketplaceScreen _reload 시작: status=$_status');
    await _loadMyBids(); // 입찰 목록도 새로고침
    setState(() {
      _future = _market.listListings(status: _status, postedBy: widget.createdByUserId);
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('오더 현황', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
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
                    return const ShimmerList(itemCount: 6, itemHeight: 110);
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
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.work_outline_rounded,
                                  size: 50,
                                  color: Colors.orange[300],
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                '현재 진행 중인 Call이 없습니다',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '아래로 당겨서 새로고침해보세요',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
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
                      final bidCount = e['bid_count'] ?? 0;
                      
                      // 현재 사용자가 오더 소유자인지 확인
                      final authService = Provider.of<AuthService>(context, listen: false);
                      final currentUserId = authService.currentUser?.id;
                      final isOwner = currentUserId == postedBy;
                      final hasBid = _myBidListingIds.contains(id);
                      final bool canBid = (status == 'open' || status == 'withdrawn' || status == 'created') && !hasBid;

                      // 상태 라벨은 이 화면에서 불필요 (항상 오픈/철회만 표시)

                      return GestureDetector(
                        onTap: () => _showCallDetail(e, alreadyBid: hasBid),
                        child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
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
                              // Header row
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF3E0),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      category,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFF57C00),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.location_on_outlined, size: 12, color: Colors.green[700]),
                                        const SizedBox(width: 4),
                                        Text(
                                          region,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 입찰자 수 배지 (오더 소유자만 표시)
                                  if (isOwner && bidCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue, width: 1.5),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.people, size: 12, color: Colors.blue),
                                          const SizedBox(width: 4),
                                          Text(
                                            '입찰 $bidCount',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Title
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
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
                                    height: 36,
                                    width: 100,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: canBid ? const Color(0xFFF57C00) : Colors.grey[300],
                                        foregroundColor: canBid ? Colors.white : Colors.grey[600],
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                    onPressed: canBid
                                        ? () async {
                                              await _claimListing(id);
                                            }
                                        : null,
                                    icon: Icon(Icons.touch_app_rounded, size: 16, color: canBid ? Colors.white : Colors.grey[600]),
                                    label: Text(
                                      hasBid ? '입찰 완료' : '잡기',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: canBid ? Colors.white : Colors.grey[600],
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
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _claimListing(String id) async {
    try {
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
      
      print('   → marketplace_service에서 오더 잡기 요청 중...');
      final ok = await _market.claimListing(id, businessId: currentUserId);
      
      if (!mounted) return;
      
      if (ok) {
        print('   ✅ 입찰 성공!');
        
        // 입찰한 오더 목록에 추가
        setState(() {
          _myBidListingIds.add(id);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('입찰이 완료되었습니다! 오더를 만든 사업자의 승인을 기다리고 있어요~'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        
        // 목록 새로고침
        await _reload();
      } else {
        print('   ❌ 오더 잡기 실패 (이미 다른 사업자가 잡았거나 오류)');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 다른 사업자가 가져갔거나 오류가 발생했습니다'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ [_claimListing] 에러 발생: $e');
      print('   StackTrace: $stackTrace');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오더 잡기 실패: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
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
    final hasBid = alreadyBid || _myBidListingIds.contains(data['id']?.toString() ?? '');
    final int bidCount = data['bid_count'] is int
        ? data['bid_count'] as int
        : int.tryParse(data['bid_count']?.toString() ?? '0') ?? 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.black),
                onPressed: () {},
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
                        // 카테고리 & 지역
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFF57C00),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 14, color: Colors.green[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    region,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // 예산
                        if (budget != null)
                          Text(
                            '예상 예산: ${budget is num ? '${(budget as num).toInt().toString()}원' : budget.toString()}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF57C00),
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
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
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
                              icon: const Icon(Icons.people, size: 20),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '입찰자 보기',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  if (bidCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$bidCount',
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: hasBid
                                  ? null
                                  : () async {
                                      Navigator.pop(context);
                                      await _claimListing(data['id'].toString());
                                    },
                              icon: Icon(Icons.touch_app_rounded, size: 20, color: hasBid ? Colors.grey[600] : Colors.white),
                              label: Text(
                                hasBid ? '입찰 완료' : '오더 잡기',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: hasBid ? Colors.grey[600] : Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasBid ? Colors.grey[300] : const Color(0xFFF57C00),
                                foregroundColor: hasBid ? Colors.grey[600] : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
  }
}


