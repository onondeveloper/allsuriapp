import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../models/estimate.dart';
import '../../providers/order_provider.dart';
import '../../providers/estimate_provider.dart';
import '../create_estimate_screen.dart';

class RequestListScreen extends StatefulWidget {
  const RequestListScreen({Key? key}) : super(key: key);

  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  @override
  void initState() {
    super.initState();
    // 주문 목록 로드
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final estimateProvider = Provider.of<EstimateProvider>(context, listen: false);
      await orderProvider.loadOrders(customerId: 'customer_123'); // 임시 고객 ID
      // 주문 목록이 로드된 후, 각 주문의 견적을 모두 불러옴
      for (final order in orderProvider.orders) {
        await estimateProvider.loadEstimatesForOrder(order.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('견적 요청 목록'),
        centerTitle: true,
      ),
      body: Consumer2<OrderProvider, EstimateProvider>(
        builder: (context, orderProvider, estimateProvider, child) {
          if (orderProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (orderProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('오류: ${orderProvider.error}'),
                  ElevatedButton(
                    onPressed: () => orderProvider.loadOrders(customerId: 'customer_123'),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          if (orderProvider.orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '견적 요청이 없습니다',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '새로운 견적 요청을 만들어보세요',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: orderProvider.orders.length,
            itemBuilder: (context, index) {
              final order = orderProvider.orders[index];
              final isOrderCompleted = order.status == Order.STATUS_COMPLETED;
              return _buildOrderCard(context, order, isOrderCompleted: isOrderCompleted);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order, {bool isOrderCompleted = false}) {
    return Card(
      margin: const EdgeInsets.all(8),
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
                    order.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(order.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              order.description,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(order.address),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('방문일: ${order.visitDate.toString().split(' ')[0]}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('요청일: ${order.formattedDate}'),
              ],
            ),
            
            // 견적 현황 표시
            if (order.status == Order.STATUS_ESTIMATING || order.status == Order.STATUS_IN_PROGRESS)
              _buildEstimateStatus(context, order),
            
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _showOrderDetail(context, order);
                  },
                  child: const Text('상세보기'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _showBidListModal(context, order);
                  },
                  child: const Text('입찰 내역'),
                ),
                if (order.status == Order.STATUS_ESTIMATING && !isOrderCompleted)
                  ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        _showEstimates(context, order);
                      },
                      child: const Text('견적 확인'),
                    ),
                  ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimateStatus(BuildContext context, Order order) {
    return Consumer<EstimateProvider>(
      builder: (context, estimateProvider, child) {
        // 해당 주문의 견적 개수 확인
        final estimates = estimateProvider.estimates.where((e) => e.orderId == order.id).toList();
        final pendingEstimates = estimates.where((e) => e.status == 'PENDING').length;
        Estimate? selectedEstimate;
        try {
          selectedEstimate = estimates.firstWhere((e) => e.status == 'SELECTED');
        } catch (_) {
          selectedEstimate = null;
        }

        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assessment, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    '견적 현황',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (selectedEstimate != null) ...[
                Text('✅ 선택된 견적: ${selectedEstimate.price.toStringAsFixed(0)}원'),
                Text('작업 기간: ${selectedEstimate.estimatedDays}일'),
              ] else if (pendingEstimates > 0) ...[
                Text('📋 $pendingEstimates개의 견적이 도착했습니다'),
                Text('견적 확인 버튼을 눌러서 확인해보세요'),
              ] else ...[
                Text('⏳ 사업자들의 견적을 기다리는 중입니다'),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showOrderDetail(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(order.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('상세 설명: ${order.description}'),
              const SizedBox(height: 8),
              Text('주소: ${order.address}'),
              const SizedBox(height: 8),
              Text('방문일: ${order.visitDate.toString().split(' ')[0]}'),
              const SizedBox(height: 8),
              Text('상태: ${_getStatusText(order.status)}'),
              const SizedBox(height: 8),
              Text('요청일: ${order.formattedDate}'),
            ],
          ),
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

  void _showEstimates(BuildContext context, Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EstimateListScreen(order: order),
      ),
    );
  }

  void _showBidListModal(BuildContext context, Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer2<EstimateProvider, OrderProvider>(
          builder: (context, estimateProvider, orderProvider, child) {
            final estimates = estimateProvider.estimates.where((e) => e.orderId == order.id).toList();
            Estimate? selectedEstimate;
            try {
              selectedEstimate = estimates.firstWhere((e) => e.status == 'SELECTED');
            } catch (_) {
              selectedEstimate = null;
            }
            final isOrderCompleted = order.status == Order.STATUS_COMPLETED;
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gavel, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text('입찰 내역', style: Theme.of(context).textTheme.titleLarge),
                        if (isOrderCompleted)
                          Container(
                            margin: const EdgeInsets.only(left: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: const Text('입찰 완료', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (estimates.isEmpty)
                      const Center(child: Text('아직 입찰이 없습니다.'))
                    else
                      ...estimates.map((estimate) {
                        final isSelected = estimate.status == 'SELECTED';
                        final isRejected = estimate.status == 'REJECTED';
                        final canAccept = !isOrderCompleted && selectedEstimate == null && estimate.status == 'PENDING';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.account_circle, color: Colors.blue.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      estimate.technicianId,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStatusBadge(estimate.status),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('견적 금액: ${estimate.price.toStringAsFixed(0)}원', style: const TextStyle(fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('설명: ${estimate.description}'),
                                const SizedBox(height: 4),
                                Text('예상 작업 기간: ${estimate.estimatedDays}일'),
                                const SizedBox(height: 4),
                                Text('제출일: ${estimate.createdAt.toString().split(' ')[0]}'),
                                if (canAccept) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('입찰 선택'),
                                            content: Text(
                                              '${estimate.price.toStringAsFixed(0)}원의 입찰을 선택하시겠습니까?\n\n선택 후에는 취소할 수 없습니다.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: const Text('취소'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.of(context).pop(true),
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                                child: const Text('선택'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          final estimateProvider = Provider.of<EstimateProvider>(context, listen: false);
                                          final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                                          await estimateProvider.acceptEstimate(estimate.id);
                                          // 주문 상태를 COMPLETED로 변경
                                          final updatedOrder = order.copyWith(status: Order.STATUS_COMPLETED);
                                          await orderProvider.updateOrder(updatedOrder);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('입찰이 성공적으로 선택되었습니다'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                            Navigator.of(context).pop(); // 모달 닫기
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('이 입찰 선택'),
                                    ),
                                  ),
                                ] else if (isSelected) ...[
                                  const SizedBox(height: 12),
                                  const Text('이 입찰이 선택되었습니다.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                ] else if (isRejected) ...[
                                  const SizedBox(height: 12),
                                  const Text('다른 입찰이 선택되어 거절되었습니다.', style: TextStyle(color: Colors.red)),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case Order.STATUS_PENDING:
        color = Colors.orange;
        text = '견적 대기';
        break;
      case Order.STATUS_ESTIMATING:
        color = Colors.blue;
        text = '견적 진행중';
        break;
      case Order.STATUS_IN_PROGRESS:
        color = Colors.green;
        text = '작업 진행중';
        break;
      case Order.STATUS_COMPLETED:
        color = Colors.grey;
        text = '완료';
        break;
      default:
        color = Colors.grey;
        text = '알 수 없음';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status) {
      case 'PENDING':
        color = Colors.orange;
        text = '대기중';
        break;
      case 'SELECTED':
        color = Colors.green;
        text = '선택됨';
        break;
      case 'REJECTED':
        color = Colors.red;
        text = '거절됨';
        break;
      default:
        color = Colors.grey;
        text = status;
    }
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case Order.STATUS_PENDING:
        return '견적 대기';
      case Order.STATUS_ESTIMATING:
        return '견적 진행중';
      case Order.STATUS_IN_PROGRESS:
        return '작업 진행중';
      case Order.STATUS_COMPLETED:
        return '완료';
      default:
        return '알 수 없음';
    }
  }
}

// 견적 목록 화면
class EstimateListScreen extends StatefulWidget {
  final Order order;

  const EstimateListScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<EstimateListScreen> createState() => _EstimateListScreenState();
}

class _EstimateListScreenState extends State<EstimateListScreen> {
  @override
  void initState() {
    super.initState();
    // 해당 주문의 견적 목록 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final estimateProvider = Provider.of<EstimateProvider>(context, listen: false);
      estimateProvider.loadEstimatesForOrder(widget.order.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 예시: 실제로는 Provider, 로그인 정보 등에서 역할을 판별해야 함
    final bool isBusinessUser = true; // 실제 구현 시 사업자 여부로 변경
    final String technicianId = '사업자 A'; // 실제 구현 시 로그인 사업자 ID로 변경
    final authService = null; // 실제 구현 시 authService 인스턴스 전달

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.order.title} - 견적 목록'),
        centerTitle: true,
      ),
      body: Consumer<EstimateProvider>(
        builder: (context, estimateProvider, child) {
          if (estimateProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final estimates = estimateProvider.estimates
              .where((e) => e.orderId == widget.order.id)
              .toList();

          if (estimates.isEmpty) {
            return Column(
              children: [
                if (isBusinessUser)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateEstimateScreen(
                                order: widget.order,
                                authService: authService,
                                technicianId: technicianId,
                              ),
                            ),
                          );
                          if (result == true) {
                            Provider.of<EstimateProvider>(context, listen: false)
                                .loadEstimatesForOrder(widget.order.id);
                          }
                        },
                        child: const Text('견적 제안하기'),
                      ),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.assessment_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '아직 견적이 없습니다',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '사업자들이 견적을 제출할 때까지 기다려주세요',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // 이미 선택된 견적이 있는지 확인
          Estimate? selectedEstimate;
          try {
            selectedEstimate = estimates.firstWhere((e) => e.status == 'SELECTED');
          } catch (_) {
            selectedEstimate = null;
          }

          return Column(
            children: [
              if (isBusinessUser)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateEstimateScreen(
                              order: widget.order,
                              authService: authService,
                              technicianId: technicianId,
                            ),
                          ),
                        );
                        if (result == true) {
                          Provider.of<EstimateProvider>(context, listen: false)
                              .loadEstimatesForOrder(widget.order.id);
                        }
                      },
                      child: const Text('견적 제안하기'),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: estimates.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final estimate = estimates[index];
                    final isSelected = estimate.status == 'SELECTED';
                    final isRejected = estimate.status == 'REJECTED';
                    final canAccept = selectedEstimate == null && estimate.status == 'PENDING';
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.green.withOpacity(0.1)
                              : isRejected
                                  ? Colors.red.withOpacity(0.05)
                                  : Colors.grey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.green
                                : isRejected
                                    ? Colors.red
                                    : Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_circle, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  estimate.technicianId,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                _buildStatusChip(estimate.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('견적 금액: ${estimate.price.toStringAsFixed(0)}원', style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('설명: ${estimate.description}'),
                            const SizedBox(height: 4),
                            Text('예상 작업 기간: ${estimate.estimatedDays}일'),
                            const SizedBox(height: 4),
                            Text('제출일: ${estimate.createdAt.toString().split(' ')[0]}'),
                            if (canAccept) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _acceptEstimate(context, estimate),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('이 견적 선택'),
                                ),
                              ),
                            ] else if (isSelected) ...[
                              const SizedBox(height: 12),
                              const Text('이 견적이 선택되었습니다.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ] else if (isRejected) ...[
                              const SizedBox(height: 12),
                              const Text('다른 견적이 선택되어 거절되었습니다.', style: TextStyle(color: Colors.red)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    switch (status) {
      case 'PENDING':
        color = Colors.orange;
        text = '대기중';
        break;
      case 'SELECTED':
        color = Colors.green;
        text = '선택됨';
        break;
      case 'REJECTED':
        color = Colors.red;
        text = '거절됨';
        break;
      default:
        color = Colors.grey;
        text = status;
    }
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _acceptEstimate(BuildContext context, Estimate estimate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('견적 선택'),
        content: Text(
          '${estimate.price.toStringAsFixed(0)}원의 견적을 선택하시겠습니까?\n\n수락 후에는 취소할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('선택'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final estimateProvider = Provider.of<EstimateProvider>(context, listen: false);
        await estimateProvider.acceptEstimate(estimate.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('견적이 성공적으로 선택되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('견적 선택 중 오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
} 