import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:allsuriapp/services/api_service.dart';
import 'package:allsuriapp/services/auth_service.dart';
import 'package:allsuriapp/services/chat_service.dart';
import 'package:allsuriapp/widgets/loading_indicator.dart';
import '../chat_screen.dart';

class OrderBiddersScreen extends StatefulWidget {
  final String listingId;
  final String orderTitle;

  const OrderBiddersScreen({
    Key? key,
    required this.listingId,
    required this.orderTitle,
  }) : super(key: key);

  @override
  State<OrderBiddersScreen> createState() => _OrderBiddersScreenState();
}

class _OrderBiddersScreenState extends State<OrderBiddersScreen> {
  List<Map<String, dynamic>> _bidders = [];
  bool _loading = true;
  String? _error;

  // 사업자 평점 평균 가져오기
  Future<Map<String, dynamic>> _getBidderRating(String bidderId) async {
    try {
      final reviews = await Supabase.instance.client
          .from('order_reviews')
          .select('rating')
          .eq('reviewee_id', bidderId);
      
      if (reviews.isEmpty) {
        return {'average': 0.0, 'count': 0};
      }
      
      final ratings = reviews.map((r) => (r['rating'] ?? 0) as int).toList();
      final average = ratings.reduce((a, b) => a + b) / ratings.length;
      
      return {'average': average, 'count': ratings.length};
    } catch (e) {
      print('⚠️ 평점 조회 실패: $e');
      return {'average': 0.0, 'count': 0};
    }
  }

  // 사업자 프로필 및 후기 보기
  Future<void> _showBidderProfile(String bidderId, String bidderName) async {
    // 후기 목록 가져오기
    List<Map<String, dynamic>> reviews = [];
    try {
      reviews = await Supabase.instance.client
          .from('order_reviews')
          .select('rating, tags, comment, created_at, reviewer_id')
          .eq('reviewee_id', bidderId)
          .order('created_at', ascending: false);
    } catch (e) {
      print('⚠️ 후기 조회 실패: $e');
    }
    
    final rating = await _getBidderRating(bidderId);
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person, color: Colors.blue, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(bidderName, style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 평점 요약
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber[700], size: 32),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '평균 ${rating['average'].toStringAsFixed(1)}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${rating['count']}개의 후기',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // 후기 목록
                if (reviews.isEmpty) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('아직 작성된 후기가 없습니다.', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                ] else ...[
                  const Text('받은 후기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...reviews.map((review) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ...List.generate(5, (i) => Icon(
                              i < (review['rating'] ?? 0) ? Icons.star : Icons.star_border,
                              color: Colors.amber[700],
                              size: 16,
                            )),
                            const SizedBox(width: 8),
                            Text('${review['rating']}.0', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (review['tags'] != null && (review['tags'] as List).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: (review['tags'] as List).take(3).map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(tag.toString(), style: const TextStyle(fontSize: 11)),
                            )).toList(),
                          ),
                        ],
                        if (review['comment'] != null && review['comment'].toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(review['comment'].toString(), 
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          review['created_at']?.toString().substring(0, 10) ?? '',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadBidders();
  }

  Future<void> _loadBidders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      print('🔍 [OrderBiddersScreen] 입찰자 목록 로드: ${widget.listingId}');
      
      final api = ApiService();
      final response = await api.get('/market/listings/${widget.listingId}/bids');
      
      print('   응답: $response');
      
      if (response['success'] == true && response['data'] is List) {
        setState(() {
          _bidders = List<Map<String, dynamic>>.from(response['data']);
          _loading = false;
        });
        print('✅ 입찰자 ${_bidders.length}명 로드 완료');
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      print('❌ [OrderBiddersScreen] 에러: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectBidder(String bidderId, String bidderName) async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사업자 선택'),
        content: Text('$bidderName 님에게 이 오더를 이관하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue, width: 2),
            ),
            child: const Text('선택하기', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      print('🔍 [OrderBiddersScreen] 사업자 선택: $bidderId');
      
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;

      if (currentUserId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
        return;
      }

      final api = ApiService();
      final response = await api.post(
        '/market/listings/${widget.listingId}/select-bidder',
        {
          'bidderId': bidderId,
          'ownerId': currentUserId,
        },
      );

      print('   응답: $response');

      if (!mounted) return;

      if (response['success'] == true) {
        print('✅ [OrderBiddersScreen] 입찰자 선택 성공');
        
        if (!mounted) return;
        
        // 채팅방 생성
        String? chatRoomId;
        try {
          print('💬 [OrderBiddersScreen] 채팅방 생성 시도...');
          print('   Owner ID: $currentUserId');
          print('   Bidder ID: $bidderId');
          print('   Listing ID: ${widget.listingId}');
          
          final chatService = ChatService();
          chatRoomId = await chatService.ensureChatRoom(
            customerId: currentUserId,
            businessId: bidderId,
            listingId: widget.listingId, // 오더 마켓플레이스 ID 전달
            title: widget.orderTitle, // 오더 제목 저장
          );
          
          print('✅ [OrderBiddersScreen] 채팅방 생성 성공: $chatRoomId');
        } catch (chatErr) {
          print('❌ [OrderBiddersScreen] 채팅방 생성 실패: $chatErr');
          // 채팅방 생성 실패해도 계속 진행
        }
        
        if (!mounted) return;
        
        // 스낵바로 성공 메시지 표시 (빠른 피드백)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $bidderName 사업자가 선택되었습니다!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // 현재 화면 닫기
        Navigator.pop(context, true);
        
        // 채팅방으로 즉시 이동 (생성에 성공한 경우)
        if (chatRoomId != null && mounted) {
          print('💬 [OrderBiddersScreen] 채팅방으로 즉시 이동: $chatRoomId');
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatRoomId: chatRoomId!,
                chatRoomTitle: '$bidderName 님과의 대화',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('선택 실패: ${response['message'] ?? '알 수 없는 오류'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ [OrderBiddersScreen] 선택 에러: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('선택 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.orderTitle),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey[300],
            height: 1,
          ),
        ),
      ),
      body: _loading
          ? const LoadingIndicator(
              message: '입찰자 목록을 불러오는 중...',
              subtitle: '잠시만 기다려주세요',
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('오류가 발생했습니다', style: TextStyle(fontSize: 18, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      Text(_error!, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadBidders,
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : _bidders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            '아직 입찰한 사업자가 없습니다',
                            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '조금만 기다려주세요!',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBidders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bidders.length,
                        itemBuilder: (context, index) {
                          final bid = _bidders[index];
                          final bidder = bid['bidder'] as Map<String, dynamic>?;
                          final status = bid['status']?.toString() ?? 'pending';
                          
                          final bidderName = bidder?['businessname']?.toString() ?? '알 수 없는 사업자';
                          final avatarUrl = bidder?['avatar_url']?.toString();
                          final estimatesCount = bidder?['estimates_created_count'] ?? 0;
                          final jobsCount = bidder?['jobs_accepted_count'] ?? 0;
                          final message = bid['message']?.toString() ?? '';
                          final createdAt = bid['created_at']?.toString() ?? '';
                          
                          // 활동 지역과 전문 분야 가져오기
                          final serviceAreas = bidder?['serviceareas'] ?? bidder?['serviceAreas'] ?? bidder?['service_areas'];
                          List<String> serviceAreasList = [];
                          if (serviceAreas is List) {
                            serviceAreasList = serviceAreas.map((e) => e.toString()).toList();
                          } else if (serviceAreas is String && serviceAreas.isNotEmpty) {
                            serviceAreasList = [serviceAreas];
                          }
                          
                          final specialties = bidder?['specialties'];
                          List<String> specialtiesList = [];
                          if (specialties is List) {
                            specialtiesList = specialties.map((e) => e.toString()).toList();
                          } else if (specialties is String && specialties.isNotEmpty) {
                            specialtiesList = [specialties];
                          }

                          return _buildBidderCard(
                            bidderId: bid['bidder_id']?.toString() ?? '',
                            bidderName: bidderName,
                            avatarUrl: avatarUrl,
                            estimatesCount: estimatesCount,
                            jobsCount: jobsCount,
                            message: message,
                            createdAt: createdAt,
                            status: status,
                            serviceAreas: serviceAreasList,
                            specialties: specialtiesList,
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildBidderCard({
    required String bidderId,
    required String bidderName,
    String? avatarUrl,
    required int estimatesCount,
    required int jobsCount,
    required String message,
    required String createdAt,
    required String status,
    List<String> serviceAreas = const [],
    List<String> specialties = const [],
  }) {
    final isPending = status == 'pending';
    final isSelected = status == 'selected';
    final isRejected = status == 'rejected';
    
    // 평점 평균 가져오기
    double averageRating = 0.0;
    int reviewCount = 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Colors.green
              : isRejected
                  ? Colors.grey[300]!
                  : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 섹션
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showBidderProfile(bidderId, bidderName),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue[100],
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Icon(Icons.person, size: 32, color: Colors.blue[700])
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showBidderProfile(bidderId, bidderName),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bidderName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 평점 평균 표시
                        FutureBuilder<Map<String, dynamic>>(
                          future: _getBidderRating(bidderId),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final avgRating = snapshot.data!['average'] ?? 0.0;
                              final count = snapshot.data!['count'] ?? 0;
                              return Row(
                                children: [
                                  Icon(Icons.star, size: 16, color: Colors.amber[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    count > 0 ? '${avgRating.toStringAsFixed(1)} ($count개 후기)' : '후기 없음',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Icon(Icons.star_outline, size: 16, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text('평가 중...', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.work_outline, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '견적 $estimatesCount건 • 완료 $jobsCount건',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                      // 활동 지역 표시
                      if (serviceAreas.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.blue[700]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                serviceAreas.take(2).join(', ') + (serviceAreas.length > 2 ? ' 외 ${serviceAreas.length - 2}곳' : ''),
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // 전문 분야 표시
                      if (specialties.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.work_outline, size: 14, color: Colors.orange[700]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                specialties.take(2).join(', ') + (specialties.length > 2 ? ' 외 ${specialties.length - 2}개' : ''),
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Text(
                      '선택됨',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (isRejected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Text(
                      '미선택',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),

            // 메시지
            if (message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  message,
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
              ),
            ],

            // 입찰 시간
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  _formatTime(createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),

            // 선택 버튼
            if (isPending) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _selectBidder(bidderId, bidderName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle, size: 20, color: Colors.white),
                  label: const Text(
                    '이 사업자 선택하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) {
        return '방금 전';
      } else if (diff.inHours < 1) {
        return '${diff.inMinutes}분 전';
      } else if (diff.inDays < 1) {
        return '${diff.inHours}시간 전';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}일 전';
      } else {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return dateStr;
    }
  }
}

