import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order.dart';
import '../order/create_order_screen.dart';

class PostOrderPage extends StatefulWidget {
  const PostOrderPage({super.key});

  @override
  State<PostOrderPage> createState() => _PostOrderPageState();
}

class _PostOrderPageState extends State<PostOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _preferredDate;
  final List<String> _selectedImages = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    const currentUserId = 'mock_customer_1'; // 실제 로그인 사용자 ID로 대체 필요

    return Scaffold(
      appBar: AppBar(
        title: const Text('견적 현황'),
      ),
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
                              await orderProvider.deleteOrder(
                                  order.id, order.customerId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('견적이 삭제되었습니다.')),
                              );
                            },
                          )
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
          );
        },
        tooltip: '견적 추가',
        child: const Icon(Icons.add),
      ),
    );
  }
}
