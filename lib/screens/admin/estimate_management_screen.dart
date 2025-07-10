import 'package:flutter/material.dart';
import '../../models/order.dart';

class EstimateManagementScreen extends StatefulWidget {
  const EstimateManagementScreen({Key? key}) : super(key: key);

  @override
  State<EstimateManagementScreen> createState() => _EstimateManagementScreenState();
}

class _EstimateManagementScreenState extends State<EstimateManagementScreen> {
  final List<Order> _orders = [
    Order(
      id: '1',
      customerId: 'test_user_1',
      title: '배관 수리 요청',
      description: '주방 배관에서 물이 새고 있습니다.',
      address: '서울시 강남구',
      visitDate: DateTime.now(),
      status: Order.STATUS_PENDING,
      createdAt: DateTime.now(),
      images: [],
      estimatedPrice: 0.0,
      customerName: '홍길동',
    ),
    Order(
      id: '2',
      customerId: 'test_user_1',
      title: '전기 수리 요청',
      description: '콘센트에서 불이 나고 있습니다.',
      address: '서울시 서초구',
      visitDate: DateTime.now(),
      status: Order.STATUS_ESTIMATING,
      createdAt: DateTime.now(),
      images: [],
      estimatedPrice: 0.0,
      customerName: '김철수',
    ),
    Order(
      id: '3',
      customerId: 'test_user_1',
      title: '에어컨 수리 요청',
      description: '에어컨이 작동하지 않습니다.',
      address: '서울시 송파구',
      visitDate: DateTime.now(),
      status: Order.STATUS_IN_PROGRESS,
      createdAt: DateTime.now(),
      images: [],
      estimatedPrice: 0.0,
      customerName: '이영희',
    ),
  ];

  String _selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('견적 관리'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _buildFilterChip('전체', 'all'),
                _buildFilterChip('견적 대기', Order.STATUS_PENDING),
                _buildFilterChip('견적 진행중', Order.STATUS_ESTIMATING),
                _buildFilterChip('작업 진행중', Order.STATUS_IN_PROGRESS),
                _buildFilterChip('완료', Order.STATUS_COMPLETED),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                if (_selectedStatus != 'all' && order.status != _selectedStatus) {
                  return const SizedBox.shrink();
                }
                return _buildOrderCard(order);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedStatus = selected ? value : 'all';
          });
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
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
            Text(order.description),
            const SizedBox(height: 8),
            Text('주소: ${order.address}'),
            const SizedBox(height: 8),
            Text('방문일: ${order.visitDate.toString().split(' ')[0]}'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // TODO: 견적 상세 페이지로 이동
                  },
                  child: const Text('상세보기'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // TODO: 견적 승인 처리
                  },
                  child: const Text('승인'),
                ),
              ],
            ),
          ],
        ),
      ),
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
} 