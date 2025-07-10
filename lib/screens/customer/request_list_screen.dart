import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart' as app_models;
import '../../models/estimate.dart';
import '../../services/services.dart';
import '../../widgets/common_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../create_estimate_screen.dart';

class RequestListScreen extends StatefulWidget {
  const RequestListScreen({Key? key}) : super(key: key);

  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  late OrderService _orderService;
  late EstimateService _estimateService;
  List<app_models.Order> _requests = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _orderService = Provider.of<OrderService>(context, listen: false);
    _estimateService = Provider.of<EstimateService>(context, listen: false);
    _loadRequests();
  }

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _orderService.fetchOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _requests = _orderService.orders;
          _isLoading = false;
        });
      }
    }
  }

  void _loadRequests() {
    // 실제 요청 목록 로딩 로직 구현
    setState(() {
      // 예시: 로딩 상태 표시 등
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 견적 요청'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '견적 요청 내역이 없습니다.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _requests.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    final estimates = _estimateService.estimates
                        .where((e) => e.orderId == request.id)
                        .toList();
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          ListTile(
                            title: Row(
                              children: [
                                Expanded(child: Text(request.title)),
                                _buildStatusChip(request.status),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        request.address,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.assignment, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '견적 ${estimates.length}개',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '요청일: ${request.formattedDate}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (request.isAwarded)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '낙찰 완료',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          OverflowBar(
                            children: [
                              TextButton(
                                onPressed: () => _showRequestDetails(request, estimates),
                                child: const Text('상세 보기'),
                              ),
                              if (estimates.isNotEmpty && !request.isAwarded)
                                ElevatedButton(
                                  onPressed: () => _showEstimates(request, estimates),
                                  child: const Text('견적 보기'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    
    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = '대기중';
        break;
      case 'in_progress':
        color = Colors.blue;
        text = '진행중';
        break;
      case 'completed':
        color = Colors.green;
        text = '완료';
        break;
      case 'cancelled':
        color = Colors.red;
        text = '취소';
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

  void _showRequestDetails(app_models.Order request, List<Estimate> estimates) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(request.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('설명: ${request.description}'),
              const SizedBox(height: 8),
              Text('주소: ${request.address}'),
              const SizedBox(height: 8),
              Text('방문 희망일: ${request.visitDate.toString().split(' ')[0]}'),
              const SizedBox(height: 8),
              Text('요청일: ${request.createdAt.toString().split('.')[0]}'),
              const SizedBox(height: 8),
              Text('견적 수: ${estimates.length}개'),
              if (request.images.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('첨부 사진: ${request.images.length}장'),
              ],
              if (request.isAwarded && request.awardedEstimateId != null) ...[
                const SizedBox(height: 8),
                Text('낙찰일: ${request.awardedAt?.toString().split('.')[0] ?? 'N/A'}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          if (estimates.isNotEmpty && !request.isAwarded)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showEstimates(request, estimates);
              },
              child: const Text('견적 보기'),
            ),
        ],
      ),
    );
  }

  void _showEstimates(app_models.Order request, List<Estimate> estimates) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${request.title} - 견적 목록'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: estimates.length,
            itemBuilder: (context, index) {
              final estimate = estimates[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${estimate.price.toStringAsFixed(0)}원'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(estimate.description),
                      const SizedBox(height: 4),
                      Text('예상 작업 기간: ${estimate.estimatedDays}일'),
                      Text('견적일: ${estimate.createdAt.toString().split('.')[0]}'),
                    ],
                  ),
                  trailing: request.isAwarded && estimate.id == request.awardedEstimateId
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '낙찰됨',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  onTap: () => _showEstimateDetail(request, estimate),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showEstimateDetail(app_models.Order request, Estimate estimate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('견적 상세'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('견적 금액: ${estimate.price.toStringAsFixed(0)}원'),
            const SizedBox(height: 8),
            Text('작업 설명: ${estimate.description}'),
            const SizedBox(height: 8),
            Text('예상 작업 기간: ${estimate.estimatedDays}일'),
            const SizedBox(height: 8),
            Text('견적일: ${estimate.createdAt.toString().split('.')[0]}'),
            if (request.isAwarded && estimate.id == request.awardedEstimateId) ...[
              const SizedBox(height: 8),
              Text('낙찰일: ${estimate.awardedAt?.toString().split('.')[0] ?? 'N/A'}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          if (!request.isAwarded)
            ElevatedButton(
              onPressed: () => _awardEstimate(request, estimate.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('이 견적으로 낙찰'),
            ),
        ],
      ),
    );
  }

  Future<void> _awardEstimate(app_models.Order request, String estimateId) async {
    try {
      final awardedOrder = request.copyWith(
        isAwarded: true,
        awardedAt: DateTime.now(),
        awardedEstimateId: estimateId,
      );
      
      setState(() {
        final index = _requests.indexWhere((o) => o.id == request.id);
        if (index != -1) {
          _requests[index] = awardedOrder;
        }
      });
      
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('견적이 성공적으로 수락되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        
        await _orderService.updateOrder(awardedOrder);
        _loadOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('견적 수락 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
