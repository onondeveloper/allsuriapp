import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/estimate.dart';
import '../../models/order.dart';
import '../../services/estimate_service.dart';
import '../../services/order_service.dart';

class BidListScreen extends StatefulWidget {
  final Order order;
  final List<Estimate> estimates;

  const BidListScreen({super.key, required this.order, required this.estimates});

  @override
  State<BidListScreen> createState() => _BidListScreenState();
}

class _BidListScreenState extends State<BidListScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
    return Scaffold(
      appBar: AppBar(title: const Text('입찰된 견적들')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: widget.estimates.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final e = widget.estimates[index];
          return Card(
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
                          e.businessName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(currency.format(e.amount), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(e.description),
                  const SizedBox(height: 8),
                  Text('예상 작업 기간: ${e.estimatedDays}일', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _award(e),
                          child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('낙찰'),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _award(Estimate estimate) async {
    setState(() => _busy = true);
    try {
      final orderService = context.read<OrderService>();
      final estimateService = context.read<EstimateService>();
      // 주문 상태 업데이트
      final updatedOrder = widget.order.copyWith(
        isAwarded: true,
        awardedAt: DateTime.now(),
        awardedEstimateId: estimate.id,
        status: Order.STATUS_IN_PROGRESS,
      );
      await orderService.updateOrder(updatedOrder);
      await estimateService.awardEstimate(estimate.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('낙찰이 완료되었습니다.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('낙찰 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}


