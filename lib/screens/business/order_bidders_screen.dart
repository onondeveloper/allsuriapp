import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:allsuriapp/services/api_service.dart';
import 'package:allsuriapp/services/auth_service.dart';

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
              backgroundColor: Colors.blue,
            ),
            child: const Text('선택하기'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$bidderName 님이 선택되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 화면 닫기
        Navigator.pop(context, true);
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
          ? const Center(child: CircularProgressIndicator())
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

                          return _buildBidderCard(
                            bidderId: bid['bidder_id']?.toString() ?? '',
                            bidderName: bidderName,
                            avatarUrl: avatarUrl,
                            estimatesCount: estimatesCount,
                            jobsCount: jobsCount,
                            message: message,
                            createdAt: createdAt,
                            status: status,
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
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue[100],
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Icon(Icons.person, size: 32, color: Colors.blue[700])
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
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
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber[700]),
                          const SizedBox(width: 4),
                          Text(
                            '견적 $estimatesCount건',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Text(
                            '완료 $jobsCount건',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
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
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text(
                    '이 사업자 선택하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

