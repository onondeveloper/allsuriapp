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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('고객 견적 요청', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadRequests,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // Modern header with category filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '카테고리',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildModernCategoryChip('all', '전체', Icons.dashboard_outlined),
                      const SizedBox(width: 10),
                      _buildModernCategoryChip('누수', '누수', Icons.water_damage_outlined),
                      const SizedBox(width: 10),
                      _buildModernCategoryChip('배관', '배관', Icons.plumbing_outlined),
                      const SizedBox(width: 10),
                      _buildModernCategoryChip('화장실', '화장실', Icons.bathroom_outlined),
                      const SizedBox(width: 10),
                      _buildModernCategoryChip('기타', '기타', Icons.more_horiz_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 견적 요청 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.inbox_outlined,
                                size: 50,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _selectedCategory == 'all' 
                                  ? '새로운 견적 요청이 없습니다'
                                  : '$_selectedCategory 견적 요청이 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '곧 새로운 요청이 들어올 거예요!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _loadRequests,
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              label: const Text('새로고침'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF1976D2).withOpacity(0.1),
                                  const Color(0xFF1976D2).withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF1976D2).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1976D2).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: Color(0xFF1976D2),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '총 ${_filteredRequests.length}개의 견적 요청 • 빠른 응답이 승률을 높입니다!',
                                    style: const TextStyle(
                                      color: Color(0xFF1976D2),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _filteredRequests.length,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemBuilder: (context, index) {
                                final request = _filteredRequests[index];
                                return _buildModernRequestCard(request);
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

  Widget _buildModernCategoryChip(String category, String label, IconData icon) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => _onCategoryChanged(category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1976D2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1976D2) : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1976D2).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernRequestCard(app_models.Order request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showRequestDetail(request),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        request.equipmentType,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1976D2),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.access_time_rounded, size: 12, color: Color(0xFFF57C00)),
                          SizedBox(width: 4),
                          Text(
                            '대기중',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFF57C00),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  request.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  request.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Info row
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(Icons.location_on_outlined, request.address.length > 20 
                        ? '${request.address.substring(0, 20)}...' 
                        : request.address),
                    _buildInfoChip(Icons.calendar_today_outlined, 
                        request.visitDate.toString().split(' ')[0]),
                    _buildInfoChip(Icons.lock_outline_rounded, '고객 정보 비공개'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showRequestDetail(request),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: const Text('상세보기', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _goToBidding(request),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('견적 제출', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showRequestDetail(app_models.Order request) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1976D2).withOpacity(0.1),
                        const Color(0xFF1976D2).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              request.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1976D2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          request.equipmentType,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(Icons.description_outlined, '설명', request.description),
                      const Divider(height: 24),
                      _buildDetailRow(Icons.location_on_outlined, '주소', request.address),
                      const Divider(height: 24),
                      _buildDetailRow(Icons.calendar_today_outlined, '방문일', 
                          request.visitDate.toString().split(' ')[0]),
                      const Divider(height: 24),
                      _buildDetailRow(Icons.lock_outline_rounded, '고객 정보', '낙찰 후 공개'),
                      const Divider(height: 24),
                      _buildDetailRow(Icons.access_time_outlined, '요청일', 
                          request.createdAt.toString().split('.')[0]),
                    ],
                  ),
                ),
                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _goToBidding(request);
                          },
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text('견적 제출', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF1976D2)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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
