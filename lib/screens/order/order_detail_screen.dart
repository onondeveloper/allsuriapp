import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../models/estimate.dart';
import '../../providers/estimate_provider.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  final String currentUserId;
  final String currentUserRole;

  const OrderDetailScreen({
    Key? key,
    required this.order,
    required this.currentUserId,
    required this.currentUserRole,
  }) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _priceController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EstimateProvider>(context, listen: false).loadEstimates(widget.order.id);
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('견적 상세')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('제목: ${widget.order.title}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('설명: ${widget.order.description}'),
            const SizedBox(height: 8),
            Text('주소: ${widget.order.address}'),
            const SizedBox(height: 8),
            Text('상태: ${widget.order.status}'),
            const SizedBox(height: 16),
            if (widget.currentUserRole == 'business') ...[
              const Divider(),
              const Text('예상 견적 제출', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: '예상 금액'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _descController,
                      decoration: const InputDecoration(labelText: '설명'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      final price = double.tryParse(_priceController.text) ?? 0.0;
                      final desc = _descController.text;
                      if (price > 0 && desc.isNotEmpty) {
                        final estimate = Estimate(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          orderId: widget.order.id,
                          technicianId: widget.currentUserId,
                          price: price,
                          description: desc,
                          estimatedDays: 1,
                          status: 'PENDING',
                          createdAt: DateTime.now(),
                        );
                        await Provider.of<EstimateProvider>(context, listen: false).addEstimate(estimate);
                        await Provider.of<EstimateProvider>(context, listen: false).loadEstimates(widget.order.id);
                        _priceController.clear();
                        _descController.clear();
                      }
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text('제출된 예상 견적', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Consumer<EstimateProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (provider.estimates.isEmpty) {
                    return const Center(child: Text('아직 제출된 예상 견적이 없습니다.'));
                  }
                  return ListView.builder(
                    itemCount: provider.estimates.length,
                    itemBuilder: (context, idx) {
                      final est = provider.estimates[idx];
                      return ListTile(
                        title: Text('${est.price.toStringAsFixed(0)}원'),
                        subtitle: Text(est.description),
                        trailing: Text(est.technicianId),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 