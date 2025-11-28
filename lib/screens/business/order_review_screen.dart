import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../widgets/loading_indicator.dart';

class OrderReviewScreen extends StatefulWidget {
  final String listingId;
  final String? jobId; // nullable로 변경
  final String revieweeId; // 리뷰 대상 사업자 ID
  final String revieweeName; // 리뷰 대상 사업자 이름
  final String orderTitle;

  const OrderReviewScreen({
    Key? key,
    required this.listingId,
    this.jobId, // nullable로 변경
    required this.revieweeId,
    required this.revieweeName,
    required this.orderTitle,
  }) : super(key: key);

  @override
  State<OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends State<OrderReviewScreen> {
  int _rating = 0;
  final Set<String> _selectedTags = {};
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _availableTags = [
    {'label': '시간을 제대로 지켜요', 'icon': Icons.access_time},
    {'label': '일을 완벽하게 처리해요', 'icon': Icons.check_circle_outline},
    {'label': '정산이 깔끔해요', 'icon': Icons.payment},
    {'label': '친절해요', 'icon': Icons.sentiment_satisfied_alt},
    {'label': '의사소통이 원활해요', 'icon': Icons.chat_bubble_outline},
    {'label': '전문성이 뛰어나요', 'icon': Icons.workspace_premium},
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('별점을 선택해주세요')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 로딩 다이얼로그
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: SmallLoadingIndicator(
                  message: '리뷰를 제출하고 있습니다...',
                ),
              ),
            ),
          ),
        );
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;

      if (currentUserId == null) throw Exception('로그인이 필요합니다');

      print('🔍 [OrderReview] 리뷰 제출 시작');
      print('   listing_id: ${widget.listingId}');
      print('   reviewee_id: ${widget.revieweeId}');
      print('   rating: $_rating');
      print('   tags: $_selectedTags');

      // 기존 리뷰 확인 (중복 방지)
      final existingReview = await Supabase.instance.client
          .from('order_reviews')
          .select('id')
          .eq('listing_id', widget.listingId)
          .eq('reviewer_id', currentUserId)
          .maybeSingle();
      
      if (existingReview != null) {
        // 이미 리뷰가 있으면 업데이트
        print('ℹ️ [OrderReview] 기존 리뷰 발견, 업데이트');
        await Supabase.instance.client.from('order_reviews').update({
          'rating': _rating,
          'tags': _selectedTags.toList(),
          'comment': _commentController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existingReview['id']);
        print('✅ [OrderReview] 리뷰 업데이트 완료');
      } else {
        // 새 리뷰 저장
        await Supabase.instance.client.from('order_reviews').insert({
          'listing_id': widget.listingId,
          'job_id': widget.jobId,
          'reviewer_id': currentUserId,
          'reviewee_id': widget.revieweeId,
          'rating': _rating,
          'tags': _selectedTags.toList(),
          'comment': _commentController.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        print('✅ [OrderReview] 리뷰 저장 완료');
      }

      // marketplace_listings 상태를 'completed'로 업데이트
      await Supabase.instance.client
          .from('marketplace_listings')
          .update({
            'status': 'completed',
            'updatedat': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.listingId);

      print('✅ [OrderReview] marketplace_listings 완료 처리');

      // jobs 상태를 'completed'로 업데이트 (jobId가 있는 경우만)
      final jobIdValue = widget.jobId;
      if (jobIdValue != null && jobIdValue.isNotEmpty) {
        await Supabase.instance.client
            .from('jobs')
            .update({
              'status': 'completed',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', jobIdValue);
        print('✅ [OrderReview] jobs 완료 처리');
      } else {
        print('ℹ️ [OrderReview] jobId 없음, jobs 업데이트 스킵');
      }

      // 리뷰 대상 사업자에게 알림 (실패해도 리뷰는 저장됨)
      try {
        await Supabase.instance.client.from('notifications').insert({
          'userid': widget.revieweeId,
          'title': '새로운 리뷰',
          'body': '${widget.orderTitle} 공사에 대한 리뷰가 등록되었습니다.',
          'type': 'review_received',
          'isread': false,
          'createdat': DateTime.now().toIso8601String(),
        });
        print('✅ [OrderReview] 알림 전송 완료');
      } catch (notifError) {
        print('⚠️ [OrderReview] 알림 전송 실패 (무시됨): $notifError');
        // 알림 실패해도 리뷰는 저장되었으므로 계속 진행
      }

      if (mounted) {
        Navigator.pop(context); // 로딩 닫기
        
        // 성공 다이얼로그
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 28),
                SizedBox(width: 12),
                Text('리뷰 등록 완료'),
              ],
            ),
            content: const Text('리뷰가 성공적으로 등록되었습니다.\n감사합니다!'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('확인'),
              ),
            ],
          ),
        );

        if (mounted) {
          Navigator.pop(context, true); // 리뷰 화면 닫기
        }
      }
    } catch (e) {
      print('❌ [OrderReview] 리뷰 제출 실패: $e');

      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop(); // 로딩 닫기

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('리뷰 제출 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('리뷰 작성'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사업자 정보 카드
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue[100],
                      child: Icon(Icons.person, size: 40, color: Colors.blue[700]),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.revieweeName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.orderTitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 별점 선택
            const Text(
              '별점을 선택해주세요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = starIndex),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        starIndex <= _rating ? Icons.star : Icons.star_border,
                        size: 48,
                        color: starIndex <= _rating ? Colors.amber : Colors.grey[400],
                      ),
                    ),
                  );
                }),
              ),
            ),
            
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _getRatingText(_rating),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber[700],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            // 태그 선택
            const Text(
              '해당하는 항목을 선택해주세요 (복수 선택 가능)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTags.map((tag) {
                final label = tag['label'] as String;
                final icon = tag['icon'] as IconData;
                final isSelected = _selectedTags.contains(label);
                
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18),
                      const SizedBox(width: 6),
                      Text(label),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(label);
                      } else {
                        _selectedTags.remove(label);
                      }
                    });
                  },
                  backgroundColor: Colors.white,
                  selectedColor: Colors.blue[50],
                  checkmarkColor: Colors.blue,
                  side: BorderSide(
                    color: isSelected ? Colors.blue : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 32),
            
            // 추가 코멘트
            const Text(
              '추가 코멘트 (선택사항)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: '더 자세한 의견을 남겨주세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 제출 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const ButtonLoadingIndicator(color: Colors.white)
                    : const Text(
                        '리뷰 제출',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return '아쉬워요';
      case 2:
        return '별로예요';
      case 3:
        return '보통이에요';
      case 4:
        return '좋아요';
      case 5:
        return '최고예요!';
      default:
        return '';
    }
  }
}

