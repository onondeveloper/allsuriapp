import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart' as app_models;
import '../../models/estimate.dart';
import '../../services/services.dart';
import '../../widgets/common_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../create_estimate_screen.dart';

class EstimateRequestsScreen extends StatefulWidget {
  const EstimateRequestsScreen({Key? key}) : super(key: key);

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
      print('=== 견적 요청 목록 로딩 시작 ===');
      
      await _orderService.fetchOrders();
      print('주문 데이터 로드 완료. 총 주문 수: ${_orderService.orders.length}');
      
      final pendingOrders = _orderService.getPendingOrders();
      print('대기 중인 견적 요청 수: ${pendingOrders.length}');
      
      setState(() {
        _requests = pendingOrders;
        _filteredRequests = _filterRequestsByCategory(pendingOrders);
        _isLoading = false;
      });
      
      print('=== 견적 요청 목록 로딩 완료 ===');
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

  // 카테고리별 필터링
  List<app_models.Order> _filterRequestsByCategory(List<app_models.Order> requests) {
    if (_selectedCategory == 'all') {
      return requests;
    }
    return requests.where((request) => request.category == _selectedCategory).toList();
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
      appBar: CommonAppBar(
        title: '견적 요청 목록',
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
                      ...app_models.Order.CATEGORIES.map((category) => 
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildCategoryChip(category, category),
                        ),
                      ).toList(),
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
                            const SizedBox(height: 8),
                            Text(
                              '총 주문 수: ${_orderService.orders.length}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
        _onCategoryChanged(category);
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildRequestCard(app_models.Order request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            title: Row(
              children: [
                Expanded(child: Text(request.title)),
                if (request.isAnonymous)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '익명',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
                    Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      request.maskedPhoneNumber,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    if (request.isAnonymous && !request.isAwarded)
                      const SizedBox(width: 8),
                    if (request.isAnonymous && !request.isAwarded)
                      Text(
                        '(낙찰 후 공개)',
                        style: TextStyle(
                          color: Colors.orange[600],
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
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
                if (request.images.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '사진 ${request.images.length}장',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          OverflowBar(
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
  }

  void _showRequestDetails(app_models.Order request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(request.title)),
            if (request.isAnonymous)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '익명',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('설명: ${request.description}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(child: Text('주소: ${request.address}')),
                ],
              ),
              const SizedBox(height: 8),
              Text('방문 희망일: ${request.visitDate.toString().split(' ')[0]}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('연락처: ${request.maskedPhoneNumber}'),
                  if (request.isAnonymous && !request.isAwarded)
                    const SizedBox(width: 8),
                  if (request.isAnonymous && !request.isAwarded)
                    Text(
                      '(낙찰 후 공개)',
                      style: TextStyle(
                        color: Colors.orange[600],
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('고객명: ${request.customerName}'),
              const SizedBox(height: 8),
              Text('요청일: ${request.createdAt.toString().split('.')[0]}'),
              if (request.images.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('첨부 사진: ${request.images.length}장'),
              ],
              if (request.isAnonymous) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '익명 사용자입니다. 견적이 낙찰된 후에만 연락처가 공개됩니다.',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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

  void _createEstimate(app_models.Order request) {
    final technicianId = _authService.currentUser?.id;

    if (technicianId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEstimateScreen(
          order: request,
          technicianId: technicianId,
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
