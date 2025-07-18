import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/estimate.dart';
import '../../models/order.dart';
import '../../services/estimate_service.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import 'create_request_screen.dart';

class CustomerMyEstimatesScreen extends StatefulWidget {
  const CustomerMyEstimatesScreen({super.key});

  @override
  State<CustomerMyEstimatesScreen> createState() => _CustomerMyEstimatesScreenState();
}

class _CustomerMyEstimatesScreenState extends State<CustomerMyEstimatesScreen> {
  List<Order> _orders = [];
  Map<String, List<Estimate>> _orderEstimates = {};
  bool _isLoading = true;
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final orderService = Provider.of<OrderService>(context, listen: false);
      final estimateService = Provider.of<EstimateService>(context, listen: false);
      
      if (authService.currentUser != null) {
        final currentUser = authService.currentUser!;
        
        // 현재 사용자의 전화번호 가져오기
        String? userPhoneNumber = currentUser.phoneNumber;
        
        if (userPhoneNumber != null) {
          // 전화번호 정규화 (하이픈, 공백 제거)
          String normalizedUserPhone = userPhoneNumber.replaceAll(RegExp(r'[-\s()]'), '');
          
          // 모든 주문을 가져온 후 전화번호로 필터링
          await orderService.loadOrders(); // 모든 주문 로드
          
          // 전화번호가 일치하는 주문만 필터링
          _orders = orderService.orders.where((order) {
            String normalizedOrderPhone = order.customerPhone.replaceAll(RegExp(r'[-\s()]'), '');
            return normalizedOrderPhone == normalizedUserPhone;
          }).toList();
        } else {
          // 전화번호가 없으면 customerId로 필터링 (기존 방식)
          await orderService.loadOrders(customerId: currentUser.id);
          _orders = orderService.orders;
        }
        
        // 각 주문에 대한 견적 목록 로드
        _orderEstimates.clear();
        for (final order in _orders) {
          await estimateService.loadEstimates(orderId: order.id);
          _orderEstimates[order.id] = List.from(estimateService.estimates);
        }
      }
    } catch (e) {
      print('데이터 로드 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Order> get filteredOrders {
    if (_selectedStatus == 'all') {
      return _orders;
    }
    
    return _orders.where((order) {
      final estimates = _orderEstimates[order.id] ?? [];
      
      switch (_selectedStatus) {
        case 'pending':
          return estimates.isEmpty && !order.isAwarded; // 견적이 없고 채택되지 않음 = 대기중
        case 'received':
          return estimates.isNotEmpty && !order.isAwarded; // 견적은 있지만 아직 채택하지 않음
        case 'awarded':
          return order.isAwarded && order.status != Order.STATUS_COMPLETED; // 견적을 채택했지만 완료되지 않음
        case 'completed':
          return order.status == Order.STATUS_COMPLETED;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('내 견적 관리'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => const CreateRequestScreen(),
              ),
            ).then((_) => _loadData());
          },
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 상태 필터
            Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatusFilter('전체', 'all'),
                    const SizedBox(width: 8),
                    _buildStatusFilter('견적 대기', 'pending'),
                    const SizedBox(width: 8),
                    _buildStatusFilter('견적 받음', 'received'),
                    const SizedBox(width: 8),
                    _buildStatusFilter('진행 중', 'awarded'),
                    const SizedBox(width: 8),
                    _buildStatusFilter('완료', 'completed'),
                  ],
                ),
              ),
            ),
            // 견적 목록
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : filteredOrders.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            final estimates = _orderEstimates[order.id] ?? [];
                            return _buildOrderCard(order, estimates);
                          },
                        ),
            ),
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
          const Icon(
            CupertinoIcons.doc_text,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 16),
          const Text(
            '견적 요청 내역이 없습니다.',
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const CreateRequestScreen(),
                ),
              ).then((_) => _loadData());
            },
            child: const Text('첫 견적 요청하기'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(String label, String status) {
    final isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? CupertinoColors.activeBlue : CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? CupertinoColors.white : CupertinoColors.black,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order, List<Estimate> estimates) {
    final canEdit = estimates.isEmpty && !order.isAwarded; // 견적이 없고 채택되지 않은 경우만 수정 가능
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          CupertinoListTile(
            title: Text(
              order.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  order.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      CupertinoIcons.location,
                      size: 14,
                      color: CupertinoColors.systemGrey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      CupertinoIcons.calendar,
                      size: 14,
                      color: CupertinoColors.systemGrey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '방문일: ${order.visitDate.toString().split(' ')[0]}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusBadge(order, estimates),
                    Text(
                      '견적 ${estimates.length}개',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(CupertinoIcons.chevron_right),
            onTap: () => _showOrderDetail(order, estimates),
          ),
          // 수정/삭제 버튼
          if (canEdit)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: CupertinoColors.systemGrey5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      onPressed: () => _editOrder(order),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.pencil, size: 16),
                          SizedBox(width: 4),
                          Text('수정'),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: CupertinoColors.systemGrey5,
                  ),
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      onPressed: () => _deleteOrder(order),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.trash, size: 16, color: CupertinoColors.systemRed),
                          SizedBox(width: 4),
                          Text('삭제', style: TextStyle(color: CupertinoColors.systemRed)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Order order, List<Estimate> estimates) {
    String text;
    Color color;
    
    if (order.status == Order.STATUS_COMPLETED) {
      text = '완료';
      color = CupertinoColors.systemGrey;
    } else if (order.isAwarded) {
      text = '진행 중';
      color = CupertinoColors.systemGreen;
    } else if (estimates.isNotEmpty) {
      text = '견적 받음';
      color = CupertinoColors.systemBlue;
    } else {
      text = '견적 대기';
      color = CupertinoColors.systemOrange;
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
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showOrderDetail(Order order, List<Estimate> estimates) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(order.title),
        message: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('설명: ${order.description}'),
            const SizedBox(height: 8),
            Text('주소: ${order.address}'),
            const SizedBox(height: 8),
            Text('방문일: ${order.visitDate.toString().split(' ')[0]}'),
            const SizedBox(height: 8),
            Text('견적 개수: ${estimates.length}개'),
          ],
        ),
        actions: [
          if (estimates.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _showEstimateList(order, estimates);
              },
              child: const Text('견적 목록 보기'),
            ),
          if (estimates.isEmpty && !order.isAwarded)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _editOrder(order);
              },
              child: const Text('수정하기'),
            ),
          if (estimates.isEmpty && !order.isAwarded)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _deleteOrder(order);
              },
              child: const Text('삭제하기', style: TextStyle(color: CupertinoColors.systemRed)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ),
    );
  }

  void _showEstimateList(Order order, List<Estimate> estimates) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('${order.title} 견적'),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ),
        child: SafeArea(
          child: ListView.builder(
            itemCount: estimates.length,
            itemBuilder: (context, index) {
              final estimate = estimates[index];
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemGrey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          estimate.businessName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (order.isAwarded && estimate.id == order.awardedEstimateId)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '채택됨',
                              style: TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.systemGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '견적 금액: ${estimate.amount.toStringAsFixed(0)}원',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.activeBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('설명: ${estimate.description}'),
                    const SizedBox(height: 8),
                    Text('예상 작업 기간: ${estimate.estimatedDays}일'),
                    const SizedBox(height: 8),
                    Text('연락처: ${estimate.businessPhone}'),
                    if (!order.isAwarded) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              onPressed: () => _rejectEstimate(order, estimate),
                              child: const Text(
                                '거절',
                                style: TextStyle(color: CupertinoColors.systemRed),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CupertinoButton.filled(
                              onPressed: () => _awardEstimate(order, estimate),
                              child: const Text('선택'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _editOrder(Order order) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => CreateRequestScreen(editingOrder: order),
      ),
    ).then((_) => _loadData());
  }

  void _deleteOrder(Order order) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('견적 요청 삭제'),
        content: Text('${order.title} 견적 요청을 삭제하시겠습니까?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await _performDeleteOrder(order);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteOrder(Order order) async {
    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      await orderService.deleteOrder(order.id);
      await _loadData();
      
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('삭제 완료'),
            content: const Text('견적 요청이 삭제되었습니다.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('오류'),
            content: Text('견적 요청 삭제 중 오류가 발생했습니다: $e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _awardEstimate(Order order, Estimate estimate) async {
    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      final estimateService = Provider.of<EstimateService>(context, listen: false);
      
      // 주문 상태 업데이트
      final updatedOrder = order.copyWith(
        isAwarded: true,
        awardedAt: DateTime.now(),
        awardedEstimateId: estimate.id,
      );
      
      await orderService.updateOrder(updatedOrder);
      await estimateService.awardEstimate(estimate.id);
      
      // 데이터 새로고침
      await _loadData();
      
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('견적 채택 완료'),
            content: Text('${estimate.businessName}의 견적이 채택되었습니다.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('오류'),
            content: Text('견적 채택 중 오류가 발생했습니다: $e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _rejectEstimate(Order order, Estimate estimate) async {
    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      final estimateService = Provider.of<EstimateService>(context, listen: false);

      // 주문 상태 업데이트 (견적 거절)
      final updatedOrder = order.copyWith(
        isAwarded: false,
        awardedAt: null,
        awardedEstimateId: null,
      );
      await orderService.updateOrder(updatedOrder);

      // 견적 상태 업데이트 (거절)
      await estimateService.rejectEstimate(estimate.id);

      // 데이터 새로고침
      await _loadData();

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);

        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('견적 거절 완료'),
            content: Text('${estimate.businessName}의 견적이 거절되었습니다.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('오류'),
            content: Text('견적 거절 중 오류가 발생했습니다: $e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }
} 