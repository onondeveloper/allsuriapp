import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../models/job.dart';
import '../business/order_bidders_screen.dart';
import '../business/order_review_screen.dart';

/// 내 오더 관리 화면
/// - 내가 생성한 오더만 표시
/// - "진행 중" 필터에 걸린 공사들 (assigned 상태)
/// - 입찰자 선택, 리뷰 작성 등 오더 소유자 기능
class MyOrderManagementScreen extends StatefulWidget {
  const MyOrderManagementScreen({Key? key}) : super(key: key);

  @override
  State<MyOrderManagementScreen> createState() => _MyOrderManagementScreenState();
}

class _MyOrderManagementScreenState extends State<MyOrderManagementScreen> {
  List<Map<String, dynamic>> _myOrders = [];
  bool _isLoading = false;
  String _filter = 'all'; // all, pending, in_progress, completed

  @override
  void initState() {
    super.initState();
    _loadMyOrders();
  }

  Future<void> _loadMyOrders() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final currentUserId = authService.currentUser?.id;

      if (currentUserId == null) {
        print('❌ [MyOrderManagement] 현재 사용자 ID가 없음');
        return;
      }

      print('🔍 [MyOrderManagement] 내가 생성한 오더 로드 시작');
      print('   현재 사용자 ID: $currentUserId');

      // marketplace_listings에서 내가 생성한 오더만 가져오기
      final listings = await Supabase.instance.client
          .from('marketplace_listings')
          .select('*, jobs(*)')
          .eq('posted_by', currentUserId)
          .order('createdat', ascending: false);

      print('🔍 [MyOrderManagement] 조회된 오더: ${listings.length}개');
      
      if (listings.isNotEmpty) {
        print('   첫 번째 오더: ${listings[0]['id']} - ${listings[0]['title']}');
        print('   posted_by: ${listings[0]['posted_by']}');
      }

      // 추가: jobs 테이블에서 내 공사 확인
      final jobs = await Supabase.instance.client
          .from('jobs')
          .select('id, title, status, owner_business_id')
          .eq('owner_business_id', currentUserId)
          .order('created_at', ascending: false);

      print('🔍 [MyOrderManagement] jobs 테이블 조회 결과: ${jobs.length}개');
      
      // 각 job에 대해 marketplace_listings를 개별 조회
      final List<Map<String, dynamic>> jobsWithListings = [];
      
      for (final job in jobs) {
        final jobId = job['id']?.toString();
        if (jobId != null) {
          try {
            final listing = await Supabase.instance.client
                .from('marketplace_listings')
                .select('*')
                .eq('jobid', jobId)
                .maybeSingle();
            
            if (listing != null) {
              jobsWithListings.add({
                ...Map<String, dynamic>.from(listing),
                'jobs': job,
              });
              print('   ✓ job $jobId → listing ${listing['id']}');
            }
          } catch (e) {
            print('   ✗ job $jobId listing 조회 실패: $e');
          }
        }
      }
      
      print('🔍 [MyOrderManagement] marketplace_listings가 있는 jobs: ${jobsWithListings.length}개');

      // 두 결과를 합치기 (중복 제거)
      final Set<String> seenIds = {};
      final List<Map<String, dynamic>> combinedOrders = [];
      
      for (final listing in listings) {
        final id = listing['id']?.toString();
        if (id != null && !seenIds.contains(id)) {
          seenIds.add(id);
          combinedOrders.add(listing);
        }
      }
      
      for (final jobWithListing in jobsWithListings) {
        final id = jobWithListing['id']?.toString();
        if (id != null && !seenIds.contains(id)) {
          seenIds.add(id);
          combinedOrders.add(jobWithListing);
        }
      }

      print('🔍 [MyOrderManagement] 최종 오더 수: ${combinedOrders.length}개');

      setState(() {
        _myOrders = combinedOrders;
      });
    } catch (e, stackTrace) {
      print('❌ [MyOrderManagement] 오더 로드 실패: $e');
      print('   StackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오더 로드 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_filter == 'all') return _myOrders;
    
    return _myOrders.where((order) {
      final status = order['status']?.toString() ?? '';
      
      switch (_filter) {
        case 'pending':
          // 입찰 대기중 (created, open)
          return status == 'created' || status == 'open';
        case 'in_progress':
          // 진행 중 (assigned)
          return status == 'assigned';
        case 'completed':
          // 완료됨 (completed, awaiting_confirmation)
          return status == 'completed' || status == 'awaiting_confirmation';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthService>().currentUser?.id ?? '';
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('내 오더 관리', style: TextStyle(fontWeight: FontWeight.w600)),
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
            onPressed: _loadMyOrders,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterChips(),
                Expanded(
                  child: _filteredOrders.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _filteredOrders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return _buildOrderCard(order, me);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChips() {
    final pendingCount = _myOrders.where((o) {
      final s = o['status']?.toString() ?? '';
      return s == 'created' || s == 'open';
    }).length;
    
    final inProgressCount = _myOrders.where((o) => o['status'] == 'assigned').length;
    
    final completedCount = _myOrders.where((o) {
      final s = o['status']?.toString() ?? '';
      return s == 'completed' || s == 'awaiting_confirmation';
    }).length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '필터',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip('전체', 'all', Icons.dashboard_outlined, _myOrders.length),
                const SizedBox(width: 10),
                _buildChip('입찰 대기', 'pending', Icons.schedule, pendingCount),
                const SizedBox(width: 10),
                _buildChip('진행 중', 'in_progress', Icons.construction_outlined, inProgressCount),
                const SizedBox(width: 10),
                _buildChip('완료', 'completed', Icons.check_circle_outline, completedCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value, IconData icon, int count) {
    final isSelected = _filter == value;
    final color = const Color(0xFFF57C00); // Orange for orders
    
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.3) : color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.orange[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.handyman_outlined,
              size: 50,
              color: Colors.orange[700],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '생성한 오더가 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '공사 등록 시 "오더로 올리기"를 선택해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, String me) {
    final String title = order['title']?.toString() ?? '제목 없음';
    final String description = order['description']?.toString() ?? '';
    final String status = order['status']?.toString() ?? '';
    final int bidCount = order['bid_count'] is int 
        ? order['bid_count'] as int 
        : int.tryParse(order['bid_count']?.toString() ?? '0') ?? 0;
    final String listingId = order['id']?.toString() ?? '';
    final budget = order['budget_amount'];
    final selectedBidderId = order['selected_bidder_id']?.toString();
    final completedBy = order['completed_by']?.toString();

    // 상태 배지
    final badge = _getBadgeForStatus(status, bidCount, selectedBidderId, completedBy);

    return Container(
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
            // Header
            Row(
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badge.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badge.icon, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        badge.label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Budget
                if (budget != null)
                  Text(
                    '₩${budget.toString()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF57C00),
                    ),
                  ),
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
            ),
            const SizedBox(height: 8),
            // Description
            if (description.isNotEmpty)
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
            
            // 입찰자 보기 버튼 (입찰이 있을 때만)
            if (bidCount > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openBidderList(listingId, title),
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: Text(
                    '입찰자 보기 ($bidCount명)', 
                    style: const TextStyle(fontWeight: FontWeight.w600)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            
            // 리뷰 작성 버튼 (완료 확인 대기 중일 때)
            if (status == 'awaiting_confirmation' && completedBy != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openReviewScreen(order),
                  icon: const Icon(Icons.star_outline, size: 18),
                  label: const Text('리뷰 작성', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _OrderBadge _getBadgeForStatus(String status, int bidCount, String? selectedBidderId, String? completedBy) {
    switch (status) {
      case 'created':
      case 'open':
        if (bidCount > 0) {
          return _OrderBadge('입찰 $bidCount건', Colors.blue, Icons.people);
        }
        return _OrderBadge('입찰 대기', Colors.orange, Icons.schedule);
      case 'assigned':
        return _OrderBadge('진행 중', Colors.green, Icons.construction);
      case 'awaiting_confirmation':
        return _OrderBadge('완료 확인 대기', Colors.purple, Icons.hourglass_empty);
      case 'completed':
        return _OrderBadge('완료', Colors.grey, Icons.check_circle);
      default:
        return _OrderBadge(status, Colors.grey, Icons.info_outline);
    }
  }

  void _openBidderList(String listingId, String orderTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderBiddersScreen(
          listingId: listingId,
          orderTitle: orderTitle,
        ),
      ),
    ).then((_) => _loadMyOrders());
  }

  Future<void> _openReviewScreen(Map<String, dynamic> order) async {
    final listingId = order['id']?.toString();
    final completedBy = order['completed_by']?.toString();
    final title = order['title']?.toString() ?? '오더';
    final jobId = order['jobid']?.toString();
    
    if (listingId == null || completedBy == null || jobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리뷰 작성 정보가 부족합니다'), backgroundColor: Colors.red),
      );
      return;
    }
    
    // Get reviewee name from users table
    String revieweeName = '사업자';
    try {
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('businessname')
          .eq('id', completedBy)
          .single();
      
      revieweeName = userResponse['businessname']?.toString() ?? '사업자';
    } catch (e) {
      print('⚠️ [MyOrderManagement] 사업자 이름 조회 실패: $e');
    }
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderReviewScreen(
          listingId: listingId,
          jobId: jobId,
          revieweeId: completedBy,
          revieweeName: revieweeName,
          orderTitle: title,
        ),
      ),
    );
    
    // 리뷰 작성 후 새로고침
    _loadMyOrders();
  }
}

class _OrderBadge {
  final String label;
  final Color color;
  final IconData icon;
  
  const _OrderBadge(this.label, this.color, this.icon);
}

