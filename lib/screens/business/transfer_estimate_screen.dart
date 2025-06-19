import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../models/role.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../order/create_order_screen.dart';

class TransferEstimateScreen extends StatefulWidget {
  const TransferEstimateScreen({Key? key}) : super(key: key);

  @override
  State<TransferEstimateScreen> createState() => _TransferEstimateScreenState();
}

class _TransferEstimateScreenState extends State<TransferEstimateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).loadOrders();
      Provider.of<UserProvider>(context, listen: false).loadBusinessUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('견적 이관'),
        centerTitle: true,
      ),
      body: Consumer<OrderProvider>(builder: (context, orderProvider, child) {
        if (orderProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (orderProvider.orders.isEmpty) {
          return const Center(child: Text('이관할 수 있는 견적이 없습니다.'));
        } else if (orderProvider.error != null) {
          return Center(child: Text('오류: ${orderProvider.error}'));
        } else {
          return ListView.builder(
            itemCount: orderProvider.orders.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final order = orderProvider.orders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(order.title),
                      subtitle: Text(
                        order.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: _buildStatusChip(order.status),
                    ),
                    ButtonBar(
                      children: [
                        TextButton(
                          onPressed: () => _showOrderDetails(order),
                          child: const Text('상세 보기'),
                        ),
                        ElevatedButton(
                          onPressed: () => _showTransferDialog(order, Provider.of<UserProvider>(context, listen: false).businessUsers),
                          child: const Text('이관하기'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        }
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateOrderScreen(customerId: 'mock_customer_1')),
          );
        },
        child: const Icon(Icons.add),
        tooltip: '견적 추가',
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case Order.STATUS_PENDING:
        color = Colors.orange;
        label = '견적 대기';
      case Order.STATUS_ESTIMATING:
        color = Colors.blue;
        label = '견적 진행중';
      case Order.STATUS_IN_PROGRESS:
        color = Colors.green;
        label = '작업 진행중';
      case Order.STATUS_COMPLETED:
        color = Colors.grey;
        label = '완료';
      default:
        color = Colors.grey;
        label = status;
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }

  void _showOrderDetails(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(order.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('설명: ${order.description}'),
            const SizedBox(height: 8),
            Text('고객 ID: ${order.customerId}'),
            const SizedBox(height: 8),
            Text('상태: ${order.status}'),
            const SizedBox(height: 8),
            Text('생성일: ${order.createdAt.toString().split('.')[0]}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showTransferDialog(order, Provider.of<UserProvider>(context, listen: false).businessUsers);
            },
            child: const Text('이관하기'),
          ),
        ],
      ),
    );
  }

  void _showTransferDialog(Order order, List<User> businesses) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('견적 이관'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\'${order.title}\' 견적을 이관할 사업자를 선택해주세요.'),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: businesses.isEmpty
                  ? const Center(child: Text('이관할 사업자가 없습니다.'))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: businesses.length,
                      itemBuilder: (context, index) {
                        final business = businesses[index];
                        return ListTile(
                          title: Text(business.businessName ?? ''),
                          subtitle: Text(business.name),
                          onTap: () => _transferEstimate(order, business),
                        );
                      },
                    ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  void _transferEstimate(Order order, User business) async {
    Navigator.pop(context);

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    try {
      final updatedOrder = order.copyWith(
        technicianId: business.id,
        status: Order.STATUS_ESTIMATING,
      );
      await orderProvider.updateOrder(updatedOrder);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${business.businessName}에게 견적이 성공적으로 이관되었습니다.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('견적 이관 중 오류 발생: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 