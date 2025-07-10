import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/estimate.dart';
import '../../services/services.dart';
import '../../widgets/common_app_bar.dart';
import '../../utils/responsive_utils.dart';
import 'package:go_router/go_router.dart';
import 'package:allsuriapp/providers/user_provider.dart';

class MyEstimatesScreen extends StatefulWidget {
  const MyEstimatesScreen({Key? key}) : super(key: key);

  @override
  State<MyEstimatesScreen> createState() => _MyEstimatesScreenState();
}

class _MyEstimatesScreenState extends State<MyEstimatesScreen> {
  late EstimateService _estimateService;
  late AuthService _authService;
  List<Estimate> _estimates = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _estimateService = Provider.of<EstimateService>(context, listen: false);
    _authService = Provider.of<AuthService>(context, listen: false);
    _loadEstimates();
  }

  Future<void> _loadEstimates() async {
    try {
      setState(() => _isLoading = true);
      print('=== 사업자 견적 목록 로딩 시작 ===');
      
      // UserProvider에서 현재 사용자 정보 가져오기
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      
      if (currentUser == null) {
        print('UserProvider에서 사용자 정보를 찾을 수 없습니다.');
        // AuthService에서도 시도
        final authUser = _authService.currentUser;
        if (authUser == null) {
          throw Exception('사용자 정보를 찾을 수 없습니다.');
        }
        print('AuthService에서 사용자 정보를 찾았습니다: ${authUser.name}');
      } else {
        print('UserProvider에서 사용자 정보를 찾았습니다: ${currentUser.name}');
      }
      
      final user = currentUser ?? _authService.currentUser!;
      final technicianId = user.id;
      
      print('현재 사업자 ID: $technicianId');
      print('현재 사업자 정보: ${user.toMap()}');

      final estimates = await _estimateService.listEstimatesByTechnician(technicianId);
      print('Firestore에서 가져온 견적 수: ${estimates.length}');
      
      // 견적 상세 정보 출력
      for (final estimate in estimates) {
        print('견적 ID: ${estimate.id}');
        print('  - 주문 ID: ${estimate.orderId}');
        print('  - 기술자 ID: ${estimate.technicianId}');
        print('  - 기술자명: ${estimate.technicianName}');
        print('  - 상태: ${estimate.status}');
        print('  - 낙찰: ${estimate.isAwarded}');
        print('  - 금액: ${estimate.formattedPrice}');
      }

      setState(() {
        _estimates = estimates;
        _isLoading = false;
      });
      
      print('=== 사업자 견적 목록 로딩 완료 ===');
      print('총 견적 수: ${_estimates.length}');
      
    } catch (e, stackTrace) {
      print('Error loading estimates: $e');
      print('스택 트레이스: $stackTrace');
      setState(() => _isLoading = false);
      
      if (mounted) {
        // build 중에 showSnackBar를 호출하지 않도록 post-frame callback 사용
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('견적 목록을 불러오는 중 오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        });
      }
    }
  }

  List<Estimate> get _filteredEstimates {
    if (_selectedStatus == 'all') {
      return _estimates;
    }
    return _estimates.where((estimate) => estimate.status == _selectedStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveUtils.isTablet(context);
    
    return Scaffold(
      appBar: CommonAppBar(
        title: '내 견적',
        showBackButton: true,
        showHomeButton: true,
      ),
      body: Column(
        children: [
          // 상태 필터
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusFilterChip('all', '전체'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip(Estimate.STATUS_PENDING, '대기'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip(Estimate.STATUS_ACCEPTED, '수락'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip(Estimate.STATUS_REJECTED, '거절'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip(Estimate.STATUS_CANCELLED, '취소'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip(Estimate.STATUS_AWARDED, '낙찰'),
                ],
              ),
            ),
          ),
          
          // 견적 목록 (실시간 업데이트)
          Expanded(
            child: _buildEstimatesStream(isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimatesStream(bool isTablet) {
    // UserProvider에서 현재 사용자 정보 가져오기
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser ?? _authService.currentUser;
    
    if (currentUser == null) {
      return const Center(
        child: Text(
          '사용자 정보를 찾을 수 없습니다.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return StreamBuilder<List<Estimate>>(
      stream: _estimateService.getEstimatesStreamByTechnician(currentUser.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _estimates.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  '견적 목록을 불러오는 중 오류가 발생했습니다.',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadEstimates,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }

        final estimates = snapshot.data ?? _estimates;
        final filteredEstimates = _selectedStatus == 'all' 
            ? estimates 
            : estimates.where((estimate) => estimate.status == _selectedStatus).toList();

        if (filteredEstimates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  '견적 내역이 없습니다.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadEstimates,
                  child: const Text('새로고침'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadEstimates,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredEstimates.length,
            itemBuilder: (context, index) {
              final estimate = filteredEstimates[index];
              return _buildEstimateCard(estimate, isTablet);
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusFilterChip(String status, String label) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = status;
        });
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildEstimateCard(Estimate estimate, bool isTablet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        estimate.isTransferEstimate ? '이관 견적' : '견적 요청',
                        style: TextStyle(
                          fontSize: 12,
                          color: estimate.isTransferEstimate ? Colors.green[600] : Colors.blue[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '견적 ID: ${estimate.id.substring(0, 8)}...',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusChip(estimate.status),
                    if (estimate.isAwarded) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '낙찰됨',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 주문 정보 또는 이관 견적 정보
            if (estimate.orderId != null) ...[
              Text(
                '주문 ID: ${estimate.orderId!.substring(0, 8)}...',
                style: const TextStyle(color: Colors.grey),
              ),
            ] else ...[
              Text(
                '고객: ${estimate.customerName ?? '미지정'}',
                style: const TextStyle(color: Colors.grey),
              ),
              Text(
                '주소: ${estimate.address ?? '미지정'}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '견적 금액: ${estimate.formattedPrice}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '작업 기간: ${estimate.estimatedDays}일',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '방문 희망일: ${estimate.formattedVisitDate}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '견적 내용:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              estimate.description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            
            // 진행 상황 표시
            _buildProgressIndicator(estimate),
            
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '작성일: ${_formatDate(estimate.createdAt)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const Spacer(),
                if (estimate.isAwarded && estimate.awardedAt != null)
                  Text(
                    '낙찰일: ${_formatDate(estimate.awardedAt!)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            
            // 고객 선택 상태 표시
            const SizedBox(height: 8),
            _buildCustomerSelectionStatus(estimate),
            
            if (estimate.status == Estimate.STATUS_PENDING) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _cancelEstimate(estimate),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('견적 취소'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _editEstimate(estimate),
                      child: const Text('견적 수정'),
                    ),
                  ),
                ],
              ),
            ],
            
            // 이관하기 버튼 (낙찰된 견적 또는 대기중인 견적에만 표시)
            if ((estimate.isAwarded || estimate.status == Estimate.STATUS_PENDING) && !estimate.isTransferEstimate) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _transferEstimate(estimate),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('이관 하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F8CFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    String statusText;

    switch (status) {
      case Estimate.STATUS_PENDING:
        backgroundColor = Colors.orange;
        statusText = '대기';
        break;
      case Estimate.STATUS_ACCEPTED:
        backgroundColor = Colors.green;
        statusText = '수락';
        break;
      case Estimate.STATUS_REJECTED:
        backgroundColor = Colors.red;
        statusText = '거절';
        break;
      case Estimate.STATUS_CANCELLED:
        backgroundColor = Colors.grey;
        statusText = '취소';
        break;
      case Estimate.STATUS_AWARDED:
        backgroundColor = Colors.purple;
        statusText = '낙찰';
        break;
      default:
        backgroundColor = Colors.grey;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _cancelEstimate(Estimate estimate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('견적 취소'),
        content: const Text('이 견적을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니오'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('취소'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _estimateService.updateEstimateStatus(estimate.id, Estimate.STATUS_CANCELLED);
      await _loadEstimates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('견적이 취소되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('견적 취소 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _editEstimate(Estimate estimate) {
    // 견적 수정 화면으로 이동
    Navigator.of(context).pushNamed('/edit-estimate', arguments: estimate);
  }

  void _transferEstimate(Estimate estimate) {
    // 견적 이관 화면으로 이동
    context.push('/business/transfer-estimate', extra: estimate);
  }

  Widget _buildProgressIndicator(Estimate estimate) {
    final steps = [
      {'status': Estimate.STATUS_PENDING, 'label': '견적 제출', 'color': Colors.orange},
      {'status': Estimate.STATUS_ACCEPTED, 'label': '고객 검토', 'color': Colors.blue},
      {'status': Estimate.STATUS_AWARDED, 'label': '낙찰', 'color': Colors.green},
    ];

    int currentStep = 0;
    for (int i = 0; i < steps.length; i++) {
      if (estimate.status == steps[i]['status'] || 
          (estimate.status == Estimate.STATUS_AWARDED && i == 2)) {
        currentStep = i;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '진행 상황',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isCompleted = index <= currentStep;
            final isCurrent = index == currentStep;

            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isCompleted ? step['color'] as Color : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCompleted ? Icons.check : Icons.circle,
                            size: 16,
                            color: isCompleted ? Colors.white : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step['label'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            color: isCurrent ? step['color'] as Color : Colors.grey[600],
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  if (index < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isCompleted ? step['color'] as Color : Colors.grey[300],
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomerSelectionStatus(Estimate estimate) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (estimate.status) {
      case Estimate.STATUS_PENDING:
        statusText = '고객 검토 대기 중';
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case Estimate.STATUS_ACCEPTED:
        statusText = '고객이 수락함';
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        break;
      case Estimate.STATUS_REJECTED:
        statusText = '고객이 거절함';
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
      case Estimate.STATUS_CANCELLED:
        statusText = '견적이 취소됨';
        statusColor = Colors.grey;
        statusIcon = Icons.block;
        break;
      case Estimate.STATUS_AWARDED:
        statusText = '고객이 선택함 (낙찰)';
        statusColor = Colors.green;
        statusIcon = Icons.emoji_events;
        break;
      default:
        statusText = '알 수 없는 상태';
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 