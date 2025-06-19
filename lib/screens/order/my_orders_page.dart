import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order.dart';
import '../order/create_order_screen.dart';
import 'order_detail_screen.dart';
import '../../models/role.dart';

class MyOrdersPage extends StatelessWidget {
  final String currentUserId;
  final String currentUserRole;

  const MyOrdersPage({
    Key? key,
    required this.currentUserId,
    required this.currentUserRole,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final title = currentUserRole == 'business' ? '내 견적(사업자)' : '내 견적(고객)';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: orderProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: orderProvider.orders.length,
              itemBuilder: (context, index) {
                final order = orderProvider.orders[index];
                return Card(
                  child: ListTile(
                    title: Text(order.title),
                    subtitle: Text(order.description),
                    trailing: order.customerId == currentUserId
                        ? IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await orderProvider.deleteOrder(order.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('견적이 삭제되었습니다.')),
                              );
                            },
                          )
                        : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailScreen(
                            order: order,
                            currentUserId: currentUserId,
                            currentUserRole: currentUserRole,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateOrderScreen(customerId: currentUserId),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: '견적 추가',
      ),
    );
  }
} 