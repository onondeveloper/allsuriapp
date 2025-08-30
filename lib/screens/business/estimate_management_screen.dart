import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../models/estimate.dart';
import '../../providers/estimate_provider.dart';
import '../../services/estimate_service.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/payment_service.dart';
import '../chat_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Call(마켓) 분리는 홈의 별도 버튼로 이동
import '../../widgets/common_app_bar.dart';

// 통합 아이템 제거 (고객 견적만 관리)

class EstimateManagementScreen extends StatefulWidget {
  final String? initialStatus;
  const EstimateManagementScreen({
    Key? key,
    this.initialStatus,
  }) : super(key: key);

  @override
  State<EstimateManagementScreen> createState() =>
      _EstimateManagementScreenState();
}

class _EstimateManagementScreenState extends State<EstimateManagementScreen> {
  late EstimateService _estimateService;
  List<Estimate> _estimates = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  // type 필터 제거 (고객 견적만)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _estimateService = Provider.of<EstimateService>(context, listen: false);
    _loadEstimates();
  }

  Future<void> _loadEstimates() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final technicianId = authService.currentUser?.id;
      if (technicianId == null) {
        throw Exception('User not logged in');
      }
      setState(() => _isLoading = true);
      await _estimateService.loadEstimates(businessId: technicianId);
      final estimates = _estimateService.estimates;
      setState(() {
        _estimates = estimates;
        _isLoading = false;
        if (widget.initialStatus != null && widget.initialStatus!.isNotEmpty) {
          _selectedStatus = widget.initialStatus!;
        }
      });
    } catch (e) {
      print('Error loading estimates: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('견적 목록을 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  List<Estimate> get _filteredEstimates {
    if (_selectedStatus == 'all') {
      return _estimates;
    }
    return _estimates
        .where((estimate) => (estimate.status).toLowerCase() == _selectedStatus.toLowerCase())
        .toList();
  }

  // 고객 견적만 표시

  Future<void> _deleteEstimate(Estimate estimate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('견적 삭제'),
        content: const Text('이 견적을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _estimateService.deleteEstimate(estimate.id);
      await _loadEstimates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('견적이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('견적 삭제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _updateEstimateStatus(
      Estimate estimate, String newStatus) async {
    try {
      await _estimateService.updateEstimateStatus(estimate.id, newStatus);
      await _loadEstimates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('견적 상태가 업데이트되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('견적 상태 업데이트 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _awardEstimate(Estimate estimate) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 견적 승인 처리
      await _estimateService.awardEstimate(estimate.id);
      // B2C 낙찰 시 플랫폼 5% 수수료 가상 알림 (주입된 서비스 사용)
      try {
        final amount = estimate.amount;
        if (amount != null) {
          // ignore: use_build_context_synchronously
          await context.read<PaymentService>().notifyB2cAwardFee(
                businessId: estimate.businessId,
                awardedAmount: amount,
              );
        }
      } catch (_) {}
      
      // 채팅방 활성화
      final chatService = ChatService();
      await chatService.activateChatRoom(estimate.id, estimate.businessId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('견적이 승인되었습니다. 채팅이 활성화되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('견적 승인 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 견적 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEstimates,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const ShimmerList(itemCount: 6, itemHeight: 110)
                : _filteredEstimates.isEmpty
                    ? const Center(child: Text('표시할 항목이 없습니다.'))
                    : ListView.builder(
                        itemCount: _filteredEstimates.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          return _buildEstimateCard(_filteredEstimates[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showCheck() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'check',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) {
        return Center(
          child: SizedBox(width: 140, height: 140, child: Lottie.asset('assets/lottie/check.json', repeat: false)),
        );
      },
    );
    Future.delayed(const Duration(milliseconds: 900), () {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildFilterChip('전체', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('대기중', Estimate.STATUS_PENDING),
          const SizedBox(width: 8),
          _buildFilterChip('선택됨', Estimate.STATUS_AWARDED),
          const SizedBox(width: 8),
          _buildFilterChip('거절됨', Estimate.STATUS_REJECTED),
          const SizedBox(width: 8),
          _buildFilterChip('완료', Estimate.STATUS_COMPLETED),
        ],
      ),
    );
  }

  // type chips 제거

  Widget _buildFilterChip(String label, String status) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = status;
        });
      },
    );
  }

  Widget _buildEstimateCard(Estimate estimate) {
    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // 제목: 주문의 title을 표시하려면 orderId로 조회 필요. 간단히 설명 첫 줄 사용
                        estimate.description.split('\n').first,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        estimate.amount != null ? currencyFormat.format(estimate.amount) : '금액 없음',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(estimate.status),
                const SizedBox(width: 6),
                _buildTypeBadge(estimate),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '예상 작업 기간: ${estimate.estimatedDays}일',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '견적 설명:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(estimate.description),
            const SizedBox(height: 8),
            Text(
              '제출일: ${DateFormat('yyyy-MM-dd HH:mm').format(estimate.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showEstimateDetails(estimate),
                    child: const Text('상세 보기'),
                  ),
                ),
                const SizedBox(width: 8),
                if (estimate.status == Estimate.STATUS_COMPLETED)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // Call 공사: 원 사업자(posted_by)와 채팅방 연결
                        final listing = await _fetchListingPoster(estimate.orderId);
                        final postedBy = listing['postedBy'] ?? '';
                        final listingId = listing['listingId'] ?? '';
                        if (postedBy.isEmpty) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('채팅 상대 정보를 찾을 수 없습니다.')),
                            );
                          }
                          return;
                        }
                        final me = context.read<AuthService>().currentUser?.id;
                        if (me == null || me.isEmpty) return;
                        final roomKey = listingId.isNotEmpty ? 'call_$listingId' : 'call_${estimate.orderId}';
                        String chatRoomId = '';
                        try {
                          chatRoomId = await ChatService().createChatRoom(roomKey, postedBy, me, estimateId: estimate.id);
                        } catch (_) {}
                        if (!mounted) return;
                        if (chatRoomId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('채팅방 생성에 실패했습니다. 다시 시도해 주세요.')),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(chatRoomId: chatRoomId, chatRoomTitle: '원 사업자와 채팅'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('채팅'),
                    ),
                  ),
                if (estimate.status == 'PENDING') ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showEditEstimateDialog(estimate),
                      child: const Text('수정'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _deleteEstimate(estimate),
                      style:
                          OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('삭제'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Call 공사 원 사업자/리스트 ID 조회: marketplace_listings에서 orderId(jobid)의 posted_by와 id를 읽음
  Future<Map<String, String>> _fetchListingPoster(String orderId) async {
    try {
      final sb = Supabase.instance.client;
      final row = await sb
          .from('marketplace_listings')
          .select('id, posted_by')
          .eq('jobid', orderId)
          .order('createdat', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return {'postedBy': '', 'listingId': ''};
      return {
        'postedBy': row['posted_by']?.toString() ?? '',
        'listingId': row['id']?.toString() ?? '',
      };
    } catch (_) {
      return {'postedBy': '', 'listingId': ''};
    }
  }


  // Call UI 제거 시작
  // Call 관련 카드 제거됨

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    String statusText;

    switch (status) {
      case Estimate.STATUS_PENDING:
        backgroundColor = Colors.orange;
        statusText = '대기중';
        break;
      case Estimate.STATUS_AWARDED:
        backgroundColor = Colors.green;
        statusText = '선택됨';
        break;
      case Estimate.STATUS_REJECTED:
        backgroundColor = Colors.grey;
        statusText = '거절됨';
        break;
      case Estimate.STATUS_COMPLETED:
        backgroundColor = Colors.blueGrey;
        statusText = '완료';
        break;
      default:
        backgroundColor = Colors.grey;
        statusText = status;
    }

    return Chip(
      label: Text(
        statusText,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: backgroundColor,
    );
  }

  // Grabbed Call 공사일 경우 배지 구분
  Widget _buildTypeBadge(Estimate estimate) {
    // Heuristic: Call grab으로 만든 견적은 createdAt과 awardedAt/transfer정보 없이 STATUS_COMPLETED로 생성됨
    final isCall = estimate.status == Estimate.STATUS_COMPLETED &&
        (estimate.transferredBy == null || estimate.transferredBy!.isEmpty);
    final color = isCall ? Colors.deepPurple : Colors.indigo;
    final label = isCall ? 'Call 공사' : '고객 견적';
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    );
  }

  void _showEstimateDetails(Estimate estimate) {
    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
    
    // 수수료 계산 (기본 5% 가정)
    final commissionRate = 0.05; // 5%
    final commissionAmount = estimate.amount * commissionRate;
    final netAmount = estimate.amount - commissionAmount;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더 (고정)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        color: Colors.blue.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '견적 상세 정보',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            '견적 ID: ${estimate.id.substring(0, 8)}...',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 스크롤 가능한 내용
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      // 견적 금액 (강조)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.blue.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade200, width: 1),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '견적 금액',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              estimate.amount != null ? currencyFormat.format(estimate.amount) : '금액 없음',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 수수료 정보 (새로 추가)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  size: 20,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '수수료 정보',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow('수수료율', '${(commissionRate * 100).toInt()}%'),
                            _buildInfoRow('수수료', currencyFormat.format(commissionAmount)),
                            _buildInfoRow('실수령액', currencyFormat.format(netAmount)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 사업자 정보 섹션
                      _buildInfoSection(
                        title: '사업자 정보',
                        icon: Icons.business,
                        iconColor: Colors.green.shade600,
                        children: [
                          _buildInfoRow('상호명', estimate.businessName),
                          _buildInfoRow('사업자 이름', estimate.businessName),
                          _buildInfoRow('연락처', estimate.businessPhone),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 견적 상세 정보 섹션
                      _buildInfoSection(
                        title: '견적 상세',
                        icon: Icons.assignment,
                        iconColor: Colors.orange.shade600,
                        children: [
                          _buildInfoRow('예상 작업 기간', '${estimate.estimatedDays}일'),
                          _buildInfoRow('설비 유형', estimate.equipmentType),
                          _buildInfoRow('상태', _getStatusText(estimate.status)),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 견적 설명
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.notes,
                                  size: 20,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '견적 설명',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              estimate.description,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade800,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 날짜 정보
                      _buildInfoSection(
                        title: '날짜 정보',
                        icon: Icons.calendar_today,
                        iconColor: Colors.purple.shade600,
                        children: [
                          _buildInfoRow('제출일', DateFormat('yyyy년 MM월 dd일 HH:mm').format(estimate.createdAt)),
                          _buildInfoRow('방문 예정일', DateFormat('yyyy년 MM월 dd일').format(estimate.visitDate)),
                          if (estimate.awardedAt != null)
                            _buildInfoRow('낙찰일', DateFormat('yyyy년 MM월 dd일').format(estimate.awardedAt!)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // 액션 버튼 (고정)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          '닫기',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 정보 섹션 위젯
  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // 정보 행 위젯
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditEstimateDialog(Estimate estimate) {
    final priceController =
        TextEditingController(text: estimate.price.toString());
    final descriptionController =
        TextEditingController(text: estimate.description);
    final daysController =
        TextEditingController(text: estimate.estimatedDays.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('견적 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: '견적 금액'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: daysController,
              decoration: const InputDecoration(labelText: '예상 작업 기간 (일)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: '견적 설명'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final updatedEstimate = estimate.copyWith(
                  amount: double.parse(priceController.text),
                  description: descriptionController.text,
                  estimatedDays: int.parse(daysController.text),
                );
                await _estimateService.updateEstimate(updatedEstimate);
                await _loadEstimates();
                Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('견적이 수정되었습니다.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('견적 수정 중 오류가 발생했습니다: $e')),
                  );
                }
              }
            },
            child: const Text('수정'),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return '대기중';
      case 'SELECTED':
        return '선택됨';
      case 'REJECTED':
        return '거절됨';
      default:
        return status;
    }
  }

  // Call 상태칩 제거됨
  // Call UI 제거 끝
}
