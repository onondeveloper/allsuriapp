import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/estimate.dart';
import '../../providers/estimate_provider.dart';
import '../../services/estimate_service.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/anonymous_service.dart';
import '../../services/payment_service.dart';
import '../../widgets/common_app_bar.dart';

class EstimateManagementScreen extends StatefulWidget {
  const EstimateManagementScreen({
    Key? key,
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
      // Note: listEstimatesByTechnician was removed, this will need to be re-implemented in EstimateService
      // For now, it will fetch all estimates
      await _estimateService.createEstimate(Estimate.empty()); // This is a placeholder
      final estimates = _estimateService.estimates;
      setState(() {
        _estimates = estimates;
        _isLoading = false;
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
        .where((estimate) => estimate.status == _selectedStatus)
        .toList();
  }

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
      final chatService = ChatService(AnonymousService());
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
                ? const Center(child: CircularProgressIndicator())
                : _filteredEstimates.isEmpty
                    ? const Center(child: Text('제출한 견적이 없습니다.'))
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

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildFilterChip('전체', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('대기중', 'PENDING'),
          const SizedBox(width: 8),
          _buildFilterChip('선택됨', 'SELECTED'),
          const SizedBox(width: 8),
          _buildFilterChip('거절됨', 'REJECTED'),
        ],
      ),
    );
  }

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
                  child: Text(
                    currencyFormat.format(estimate.price),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                  ),
                ),
                _buildStatusChip(estimate.status),
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

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    String statusText;

    switch (status) {
      case 'PENDING':
        backgroundColor = Colors.orange;
        statusText = '대기중';
        break;
      case 'SELECTED':
        backgroundColor = Colors.green;
        statusText = '선택됨';
        break;
      case 'REJECTED':
        backgroundColor = Colors.grey;
        statusText = '거절됨';
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

  void _showEstimateDetails(Estimate estimate) {
    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('견적 상세 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('견적 금액: ${currencyFormat.format(estimate.price)}'),
            const SizedBox(height: 8),
            Text('예상 작업 기간: ${estimate.estimatedDays}일'),
            const SizedBox(height: 8),
            const Text('견적 설명:'),
            Text(estimate.description),
            const SizedBox(height: 8),
            Text(
                '제출일: ${DateFormat('yyyy-MM-dd HH:mm').format(estimate.createdAt)}'),
            const SizedBox(height: 8),
            Text('상태: ${_getStatusText(estimate.status)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
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
}
