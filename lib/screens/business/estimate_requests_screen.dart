import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart' as app_models;
import '../../models/estimate.dart';
import '../../services/order_service.dart';
import '../../services/estimate_service.dart';
import '../../services/auth_service.dart';
import '../create_estimate_screen.dart';

class EstimateRequestsScreen extends StatefulWidget {
  const EstimateRequestsScreen({super.key});

  @override
  State<EstimateRequestsScreen> createState() => _EstimateRequestsScreenState();
}

class _EstimateRequestsScreenState extends State<EstimateRequestsScreen> {
  late OrderService _orderService;
  late EstimateService _estimateService;
  late AuthService _authService;
  List<app_models.Order> _requests = [];
  List<app_models.Order> _filteredRequests = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequests();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _orderService = Provider.of<OrderService>(context, listen: false);
    _estimateService = Provider.of<EstimateService>(context, listen: false);
    _authService = Provider.of<AuthService>(context, listen: false);
  }

  Future<void> _loadRequests() async {
    try {
      setState(() => _isLoading = true);
      
      // 모든 주문 가져오기
      final allOrders = await _orderService.getOrders();
      
      // 견적 요청 가능한 주문 필터링 (pending 상태이고 아직 채택되지 않은 것)
      final availableOrders = allOrders.where((order) => 
        order.status == 'pending' && !order.isAwarded
      ).toList();
      
      setState(() {
        _requests = availableOrders;
        _filteredRequests = _filterRequestsByCategory(availableOrders);
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('견적 요청 목록을 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  // 카테고리별 필터링
  List<app_models.Order> _filterRequestsByCategory(List<app_models.Order> requests) {
    if (_selectedCategory == 'all') {
      return requests;
    }
    String mapCategory(String? raw) {
      final v = (raw ?? '').trim();
      if (v.contains('누수')) return '누수';
      if (v.contains('배관') || v.contains('보일러') || v.contains('난방')) return '배관';
      if (v.contains('화장실') || v.contains('욕실') || v.contains('변기')) return '화장실';
      return '기타';
    }
    return requests.where((request) => mapCategory(request.equipmentType) == _selectedCategory).toList();
  }

  // 카테고리 필터 변경
  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
      _filteredRequests = _filterRequestsByCategory(_requests);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('견적 요청 목록'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          // 카테고리 필터
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '카테고리 필터',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('all', '전체'),
                      const SizedBox(width: 8),
                      _buildCategoryChip('누수', '누수'),
                      const SizedBox(width: 8),
                      _buildCategoryChip('배관', '배관'),
                      const SizedBox(width: 8),
                      _buildCategoryChip('화장실', '화장실'),
                      const SizedBox(width: 8),
                      _buildCategoryChip('기타', '기타'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 견적 요청 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_outlined,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _selectedCategory == 'all' 
                                  ? '새로운 견적 요청이 없습니다.'
                                  : '$_selectedCategory 카테고리의 견적 요청이 없습니다.',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadRequests,
                              child: const Text('새로고침'),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.blue[50],
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '총 ${_filteredRequests.length}개의 견적 요청이 있습니다. 견적을 작성하여 고객에게 제안해보세요!',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _filteredRequests.length,
                              padding: const EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                final request = _filteredRequests[index];
                                return _buildRequestCard(request);
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, String label) {
    final isSelected = _selectedCategory == category;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _onCategoryChanged(category);
        }
      },
    );
  }

  Widget _buildRequestCard(app_models.Order request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '견적 대기',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '카테고리: ${request.equipmentType}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              request.description,
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.address,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '방문일: ${request.visitDate.toString().split(' ')[0]}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 고객 개인정보 비표시 (앱 이탈 방지)
            Row(
              children: const [
                Icon(Icons.person, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text('고객 정보: 낙찰 후 공개',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRequestDetail(request),
                    child: const Text('상세보기'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _goToBidding(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('입찰하기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestDetail(app_models.Order request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(request.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('카테고리: ${request.equipmentType}'),
              const SizedBox(height: 8),
              Text('설명: ${request.description}'),
              const SizedBox(height: 8),
              Text('주소: ${request.address}'),
              const SizedBox(height: 8),
              Text('방문일: ${request.visitDate.toString().split(' ')[0]}'),
              const SizedBox(height: 8),
              const Text('고객: 비공개'),
              const SizedBox(height: 8),
              const Text('연락처: 낙찰 후 공개'),
              const SizedBox(height: 8),
              Text('요청일: ${request.createdAt.toString().split('.')[0]}'),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _goToBidding(request);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('입찰하기'),
            ),
          ),
        ],
      ),
    );
  }

  void _goToBidding(app_models.Order request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEstimateScreen(order: request),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
