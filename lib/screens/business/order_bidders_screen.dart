import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:allsuriapp/services/api_service.dart';
import 'package:allsuriapp/services/auth_service.dart';
import 'package:allsuriapp/services/chat_service.dart';
import 'package:allsuriapp/services/notification_service.dart';
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
      } else {
        throw Exception('데이터 형식이 올바르지 않습니다');
      }
    } catch (e) {
      print('❌ [OrderBiddersScreen] 로드 오류: $e');
      setState(() {
        _error = '입찰자 목록을 불러오는데 실패했습니다';
        _loading = false;
      });
    }
  }

  Future<void> _selectBidder(String bidderId, String bidderName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('입찰자 선택'),
        content: Text('$bidderName님을 선택하시겠습니까?\n선택하면 다른 입찰은 거절되며 채팅방이 생성됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('선택하기'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 로딩 표시
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      print('🔍 [OrderBiddersScreen] 입찰자 선택 시작');
      
      // 현재 사용자 ID 확인
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;
      
      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('사용자 정보를 찾을 수 없습니다. 다시 로그인해주세요.');
      }
      
      final api = ApiService();
      final response = await api.post('/market/listings/${widget.listingId}/select-bidder', {
        'bidderId': bidderId,
        'ownerId': currentUserId,
      });

      print('✅ [OrderBiddersScreen] API 응답: $response');

      if (response['success'] == true) {
        // 🔧 awarded_amount 업데이트 (오더 예산을 공사 금액으로 저장)
        try {
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('💰 [OrderBiddersScreen] awarded_amount 업데이트 시작');
          
          // 1. marketplace_listings의 budget_amount 조회
          final listingData = await Supabase.instance.client
              .from('marketplace_listings')
              .select('budget_amount')
              .eq('id', widget.listingId)
              .single();
          
          final budgetAmount = listingData['budget_amount'];
          print('   오더 예산 금액: $budgetAmount');
          
          // 2. jobs 테이블의 awarded_amount 업데이트
          if (budgetAmount != null && response['data']?['jobId'] != null) {
            final jobId = response['data']['jobId'];
            print('   Job ID: $jobId');
            
            await Supabase.instance.client
                .from('jobs')
                .update({'awarded_amount': budgetAmount})
                .eq('id', jobId);
            
            print('✅ [OrderBiddersScreen] awarded_amount 업데이트 완료: $budgetAmount원');
          } else {
            print('⚠️ [OrderBiddersScreen] budgetAmount 또는 jobId가 없음');
          }
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        } catch (amountErr) {
          print('❌ [OrderBiddersScreen] awarded_amount 업데이트 실패 (무시됨): $amountErr');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        }
        
        // 채팅방 생성 및 이동
        if (!mounted) return;
        
        // 로딩 닫기
        Navigator.pop(context); 
        
        // 성공 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$bidderName님이 선택되었습니다. 채팅방으로 이동합니다.')),
        );

        // 1️⃣ 낙찰 알림 발송
        try {
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('📤 [OrderBiddersScreen] 낙찰 알림 발송 시작');
          print('   수신자 ID: $bidderId');
          print('   오더 제목: ${widget.orderTitle}');
          print('   오더 ID: ${widget.listingId}');
          
          final notificationService = NotificationService();
          await notificationService.sendNotification(
            userId: bidderId, // 낙찰받은 사업자에게
            title: '🎉 낙찰 축하드립니다!',
            body: '[${widget.orderTitle}] 오더에 낙찰되었습니다.',
            type: 'bid_selected', // ⚠️ bid_awarded → bid_selected로 변경
            orderId: widget.listingId,
            jobTitle: widget.orderTitle,
          );
          print('✅ [OrderBiddersScreen] 낙찰 알림 발송 완료!');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        } catch (notiErr) {
          print('❌ [OrderBiddersScreen] 낙찰 알림 발송 실패: $notiErr');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        }

        // 2️⃣ 채팅방 생성/이동
        try {
          // ChatService를 통해 채팅방 생성/조회
          print('🔍 [OrderBiddersScreen] 채팅방 생성 시도');
          print('   Owner ID: $currentUserId');
          print('   Bidder ID: $bidderId');
          print('   Listing ID: ${widget.listingId}');
          
          final chatService = ChatService();
          final chatRoomId = await chatService.ensureChatRoom(
            customerId: currentUserId,
            businessId: bidderId,
            listingId: widget.listingId, // 오더 마켓플레이스 ID 전달
            title: widget.orderTitle, // 오더 제목 저장
          );
          
          print('✅ [OrderBiddersScreen] 채팅방 생성 성공: $chatRoomId');
          
          // 3️⃣ 자동 환영 메시지 발송
          try {
            print('📤 [OrderBiddersScreen] 자동 환영 메시지 발송 중...');
            final welcomeMessage = '안녕하세요. [${widget.orderTitle}] 공사로 연락 드립니다.';
            await chatService.sendMessage(
              chatRoomId,
              welcomeMessage,
              currentUserId,
            );
            print('✅ [OrderBiddersScreen] 자동 환영 메시지 발송 완료: $welcomeMessage');
            
            // 4️⃣ 채팅 알림 발송
            try {
              print('📤 [OrderBiddersScreen] 채팅 알림 발송 중...');
              
              // 현재 사용자 이름 가져오기
              final currentUserName = authService.currentUser?.businessName ?? 
                                      authService.currentUser?.name ?? 
                                      '오더 발주자';
              
              final notificationService = NotificationService();
              await notificationService.sendNotification(
                userId: bidderId, // 낙찰받은 사업자에게
                title: '💬 새로운 메시지',
                body: '[${widget.orderTitle}] - $currentUserName: $welcomeMessage',
                type: 'chat_message',
                chatRoomId: chatRoomId,
              );
              print('✅ [OrderBiddersScreen] 채팅 알림 발송 완료');
            } catch (chatNotiErr) {
              print('⚠️ [OrderBiddersScreen] 채팅 알림 발송 실패 (무시됨): $chatNotiErr');
            }
          } catch (msgErr) {
            print('⚠️ [OrderBiddersScreen] 자동 메시지 발송 실패 (무시됨): $msgErr');
            // 메시지 실패해도 채팅방은 열림
          }
          
          // 채팅방으로 이동
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatRoomId: chatRoomId,
                  chatRoomTitle: bidderName,
                ),
              ),
            );
          }
        } catch (chatErr) {
          print('❌ [OrderBiddersScreen] 채팅방 생성 실패: $chatErr');
          print('   에러 타입: ${chatErr.runtimeType}');
          print('   에러 상세: ${chatErr.toString()}');
          
          // 채팅방 생성 실패해도 낙찰은 성공했으므로 메시지 표시
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('낙찰은 완료되었으나 채팅방 생성에 실패했습니다: ${chatErr.toString()}'),
                duration: const Duration(seconds: 5),
              ),
            );
            Navigator.pop(context); // 입찰자 목록 화면 닫기
          }
        }
      } else {
        throw Exception(response['message'] ?? '입찰자 선택 실패');
      }
    } catch (e) {
      print('❌ [OrderBiddersScreen] 선택 오류: $e');
      print('   에러 타입: ${e.runtimeType}');
      print('   에러 상세: ${e.toString()}');
      
      if (mounted) {
        Navigator.pop(context); // 로딩 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('입찰자 목록'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: LoadingIndicator(message: '입찰자 정보를 불러오고 있습니다...'))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBidders,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : _bidders.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('아직 입찰자가 없습니다'),
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
                            jobsCount: jobsCount is int ? jobsCount : int.tryParse(jobsCount.toString()) ?? 0,
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
                              '완료 $jobsCount건',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 활동 지역 & 전문 분야
            if (serviceAreas.isNotEmpty || specialties.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (serviceAreas.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              serviceAreas.take(2).join(', ') + (serviceAreas.length > 2 ? ' 외 ${serviceAreas.length - 2}곳' : ''),
                              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (serviceAreas.isNotEmpty && specialties.isNotEmpty)
                      const SizedBox(height: 4),
                    if (specialties.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.work, size: 14, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              specialties.take(2).join(', ') + (specialties.length > 2 ? ' 외 ${specialties.length - 2}개' : ''),
                              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 메시지
            if (message.isNotEmpty) ...[
              Container(
                width: double.infinity,
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
              const SizedBox(height: 12),
            ],

            // 입찰 시간
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

            // 선택됨 배지
            if (isSelected) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: const Center(
                  child: Text(
                    '선택됨',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],

            // 미선택 배지
            if (isRejected) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: Center(
                  child: Text(
                    '미선택',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],

            // 선택 버튼 (대기 상태일 때만)
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
