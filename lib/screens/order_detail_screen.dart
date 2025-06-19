import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/estimate.dart';
import '../services/estimate_service.dart';
import '../services/order_service.dart';
import '../widgets/estimate_list_item.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/estimate_provider.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  final AuthService authService;
  final OrderService orderService;

  const OrderDetailScreen({
    Key? key,
    required this.order,
    required this.authService,
    required this.orderService,
  }) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late EstimateService _estimateService;
  List<Estimate> _estimates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _estimateService = EstimateService(widget.authService);
    _loadEstimates();
  }

  Future<void> _loadEstimates() async {
    try {
      final estimates = await _estimateService.listEstimatesForOrder(widget.order.id);
      setState(() {
        _estimates = estimates;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading estimates: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('견적 요청 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEstimates,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderDetails(),
              const SizedBox(height: 24),
              _buildEstimatesList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.order.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '상태: ${_getStatusText(widget.order.status)}',
              style: TextStyle(
                color: _getStatusColor(widget.order.status),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text('주소: ${widget.order.address}'),
            const SizedBox(height: 8),
            Text('방문 희망일: ${widget.order.visitDate.toString().split(' ')[0]}'),
            const SizedBox(height: 16),
            Text(
              '상세 내용',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(widget.order.description),
            if (widget.order.images.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '첨부 이미지',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.order.images.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Image.network(
                        widget.order.images[index],
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEstimatesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '견적 목록',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton.icon(
              onPressed: _loadEstimates,
              icon: const Icon(Icons.refresh),
              label: const Text('새로고침'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_estimates.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.description_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '아직 제안된 견적이 없습니다.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _estimates.length,
            itemBuilder: (context, index) {
              return EstimateListItem(
                estimate: _estimates[index],
                isSelected: widget.order.selectedEstimateId == _estimates[index].id,
                onSelect: () => _selectEstimate(_estimates[index]),
              );
            },
          ),
      ],
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return '견적 대기중';
      case 'ESTIMATING':
        return '견적 진행중';
      case 'IN_PROGRESS':
        return '작업 진행중';
      case 'COMPLETED':
        return '완료';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'ESTIMATING':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.green;
      case 'COMPLETED':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  Future<void> _selectEstimate(Estimate estimate) async {
    try {
      // 사용자 확인
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('견적 선택'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('다음 견적을 선택하시겠습니까?'),
              const SizedBox(height: 16),
              Text('금액: ${NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(estimate.price)}'),
              Text('예상 기간: ${estimate.estimatedDays}일'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('선택'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() => _isLoading = true);

      // 1. 선택된 견적의 상태를 SELECTED로 변경
      await _estimateService.updateEstimateStatus(estimate.id, 'SELECTED');

      // 2. 다른 견적들의 상태를 REJECTED로 변경
      final otherEstimates = _estimates.where((e) => e.id != estimate.id);
      for (final otherEstimate in otherEstimates) {
        await _estimateService.updateEstimateStatus(otherEstimate.id, 'REJECTED');
      }

      // 3. 주문 상태 업데이트
      final updatedOrder = widget.order.copyWith(
        status: 'IN_PROGRESS',
        selectedEstimateId: estimate.id,
        estimatedPrice: estimate.price,
        technicianId: estimate.technicianId,
      );

      await widget.orderService.updateOrder(updatedOrder);

      // 4. 견적 목록 새로고침
      await _loadEstimates();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('견적이 선택되었습니다.')),
        );
      }
    } catch (e) {
      print('Error selecting estimate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('견적 선택 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
} 