import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/estimate.dart';
import '../../providers/estimate_provider.dart';

class MyEstimatesScreen extends StatefulWidget {
  final String technicianId;
  const MyEstimatesScreen({Key? key, required this.technicianId}) : super(key: key);

  @override
  State<MyEstimatesScreen> createState() => _MyEstimatesScreenState();
}

class _MyEstimatesScreenState extends State<MyEstimatesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EstimateProvider>(context, listen: false).notifyListeners();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 견적 현황'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '내가 입찰한 견적'),
            Tab(text: '진행중인 견적'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyEstimatesTab(),
          _buildInProgressTab(),
        ],
      ),
    );
  }

  Widget _buildMyEstimatesTab() {
    return Consumer<EstimateProvider>(
      builder: (context, provider, child) {
        final myEstimates = provider.getEstimatesForTechnician(widget.technicianId);
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (myEstimates.isEmpty) {
          return const Center(child: Text('입찰한 견적이 없습니다.'));
        }
        return ListView.builder(
          itemCount: myEstimates.length,
          itemBuilder: (context, idx) => _buildEstimateCard(myEstimates[idx]),
        );
      },
    );
  }

  Widget _buildInProgressTab() {
    return Consumer<EstimateProvider>(
      builder: (context, provider, child) {
        final selectedEstimates = provider.getSelectedEstimatesForTechnician(widget.technicianId);
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (selectedEstimates.isEmpty) {
          return const Center(child: Text('진행중인 견적이 없습니다.'));
        }
        return ListView.builder(
          itemCount: selectedEstimates.length,
          itemBuilder: (context, idx) => _buildEstimateCard(selectedEstimates[idx]),
        );
      },
    );
  }

  Widget _buildEstimateCard(Estimate estimate) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('주문 ID: ${estimate.orderId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                _buildStatusChip(estimate.status),
              ],
            ),
            const SizedBox(height: 8),
            Text('견적 금액: ${estimate.price.toStringAsFixed(0)}원'),
            Text('설명: ${estimate.description}'),
            Text('예상 작업 기간: ${estimate.estimatedDays}일'),
            Text('제출일: ${estimate.createdAt.toString().split(' ')[0]}'),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
} 