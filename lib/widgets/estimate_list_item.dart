import 'package:flutter/material.dart';
import '../models/estimate.dart';
import 'package:intl/intl.dart';

class EstimateListItem extends StatelessWidget {
  final Estimate estimate;
  final bool isSelected;
  final VoidCallback onSelect;

  const EstimateListItem({
    Key? key,
    required this.estimate,
    required this.isSelected,
    required this.onSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'ko_KR',
      symbol: '₩',
      decimalDigits: 0,
    );

    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currencyFormat.format(estimate.price),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '예상 작업 기간: ${estimate.estimatedDays}일',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text(
              '견적 설명',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(estimate.description),
            const SizedBox(height: 16),
            Text(
              '견적 제안일: ${DateFormat('yyyy-MM-dd').format(estimate.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!isSelected && estimate.status == 'PENDING')
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSelect,
                    child: const Text('이 견적 선택하기'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color backgroundColor;
    String statusText;

    switch (estimate.status) {
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
        statusText = estimate.status;
    }

    return Chip(
      label: Text(
        statusText,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: backgroundColor,
    );
  }
} 