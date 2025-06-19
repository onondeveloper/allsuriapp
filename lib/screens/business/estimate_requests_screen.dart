import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../screens/create_estimate_screen.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';

class EstimateRequestsScreen extends StatefulWidget {
  const EstimateRequestsScreen({Key? key}) : super(key: key);

  @override
  State<EstimateRequestsScreen> createState() => _EstimateRequestsScreenState();
}

class _EstimateRequestsScreenState extends State<EstimateRequestsScreen> {
  late OrderService _orderService;
  List<Order> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 테스트용 dummy authService
    final dummyAuthService = AuthService();
    _orderService = OrderService(dummyAuthService);
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      setState(() => _isLoading = true);
      // 견적 대기중인 주문들을 가져옴
      final pendingOrders = await _orderService.getPendingOrders();
      setState(() {
        _requests = pendingOrders;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading requests: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('견적 요청 목록을 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('견적 요청 목록'),
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
                      Icon(Icons.description_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '새로운 견적 요청이 없습니다.',
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(request.title),
                            subtitle: Text(
                              request.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              '요청일: ${request.createdAt.toString().split(' ')[0]}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          ButtonBar(
                            children: [
                              TextButton(
                                onPressed: () => _showRequestDetails(request),
                                child: const Text('상세 보기'),
                              ),
                              ElevatedButton(
                                onPressed: () => _createEstimate(request),
                                child: const Text('견적 작성'),
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

  void _showRequestDetails(Order request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(request.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('설명: ${request.description}'),
            const SizedBox(height: 8),
            Text('주소: ${request.address}'),
            const SizedBox(height: 8),
            Text('방문 희망일: ${request.visitDate.toString().split(' ')[0]}'),
            const SizedBox(height: 8),
            Text('고객 ID: ${request.customerId}'),
            const SizedBox(height: 8),
            Text('요청일: ${request.createdAt.toString().split('.')[0]}'),
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
              _createEstimate(request);
            },
            child: const Text('견적 작성'),
          ),
        ],
      ),
    );
  }

  void _createEstimate(Order request) {
    // 테스트용 dummy authService와 technicianId
    final dummyAuthService = AuthService();
    final dummyTechnicianId = 'tech_${DateTime.now().millisecondsSinceEpoch}';
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEstimateScreen(
          order: request,
          authService: dummyAuthService,
          technicianId: dummyTechnicianId,
        ),
      ),
    ).then((result) {
      // 견적 작성 완료 후 목록 새로고침
      if (result == true) {
        _loadRequests();
      }
    });
  }
} 