import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart' as app_models;
import '../../models/estimate.dart';
import '../../services/services.dart';
import '../../widgets/common_app_bar.dart';
import '../../utils/responsive_utils.dart';
import 'package:allsuriapp/providers/user_provider.dart';
import 'package:go_router/go_router.dart';

class CustomerMyEstimatesScreen extends StatefulWidget {
  const CustomerMyEstimatesScreen({Key? key}) : super(key: key);

  @override
  State<CustomerMyEstimatesScreen> createState() => _CustomerMyEstimatesScreenState();
}

class _CustomerMyEstimatesScreenState extends State<CustomerMyEstimatesScreen> {
  late OrderService _orderService;
  late EstimateService _estimateService;
  late AuthService _authService;
  List<app_models.Order> _myOrders = [];
  Map<String, List<Estimate>> _orderEstimates = {};
  bool _isLoading = true;
  String? _selectedStatus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _orderService = Provider.of<OrderService>(context, listen: false);
    _estimateService = Provider.of<EstimateService>(context, listen: false);
    _authService = Provider.of<AuthService>(context, listen: false);
    _loadMyEstimates();
  }

  // 전화번호 정규화 함수
  String _normalizePhoneNumber(String? phone) {
    if (phone == null) return '';
    // 하이픈, 공백, 괄호 제거
    return phone.replaceAll(RegExp(r'[-\s()]'), '');
  }

  Future<void> _loadMyEstimates() async {
    try {
      setState(() => _isLoading = true);
      print('=== 고객 견적 내역 로딩 시작 ===');
      
      await _orderService.fetchOrders();
      print('전체 주문 수: ${_orderService.orders.length}');
      
      // UserProvider에서 현재 사용자 정보 가져오기
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      
      if (currentUser == null) {
        print('UserProvider에서 사용자 정보를 찾을 수 없습니다.');
        // AuthService에서도 시도
        final authUser = _authService.currentUser;
        if (authUser == null) {
          throw Exception('사용자 정보를 찾을 수 없습니다.');
        }
        print('AuthService에서 사용자 정보를 찾았습니다: ${authUser.name}');
      } else {
        print('UserProvider에서 사용자 정보를 찾았습니다: ${currentUser.name}');
      }
      
      final user = currentUser ?? _authService.currentUser!;
      print('현재 사용자: ${user.name}, 전화번호: ${user.phoneNumber}, 익명: ${user.isAnonymous}');
      
      // 사용자의 주문 목록 가져오기
      List<app_models.Order> myOrders;
      
      // customerId와 전화번호 모두로 주문 찾기
      final normalizedUserPhone = _normalizePhoneNumber(user.phoneNumber);
      print('사용자 전화번호로 주문 검색: $normalizedUserPhone');
      print('사용자 ID로 주문 검색: ${user.id}');
      
      myOrders = _orderService.orders.where((order) {
        final normalizedOrderPhone = _normalizePhoneNumber(order.customerPhone);
        final phoneMatches = normalizedOrderPhone == normalizedUserPhone;
        final idMatches = order.customerId == user.id;
        final matches = phoneMatches || idMatches;
        
        print('주문 ${order.id}:');
        print('  - customerId: ${order.customerId} (매칭: $idMatches)');
        print('  - customerPhone: ${order.customerPhone} (정규화: $normalizedOrderPhone) (매칭: $phoneMatches)');
        print('  - 최종 매칭: $matches');
        
        return matches;
      }).toList();
      
      print('사용자의 주문 수: ${myOrders.length}');
      
      // 각 주문에 대한 견적 목록 가져오기
      final Map<String, List<Estimate>> orderEstimates = {};
      for (final order in myOrders) {
        print('주문 ${order.id}의 견적 목록 조회 중...');
        final estimates = await _estimateService.listEstimatesForOrder(order.id);
        orderEstimates[order.id] = estimates;
        print('주문 ${order.id}의 견적 수: ${estimates.length}');
      }
      
      setState(() {
        _myOrders = myOrders;
        _orderEstimates = orderEstimates;
        _isLoading = false;
      });
      
      print('=== 고객 견적 내역 로딩 완료 ===');
      print('총 주문 수: ${_myOrders.length}');
      print('총 견적 수: ${_orderEstimates.values.expand((e) => e).length}');
      
    } catch (e, stackTrace) {
      print('Error loading my estimates: $e');
      print('스택 트레이스: $stackTrace');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('견적 내역을 불러오는 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<app_models.Order> get _filteredOrders {
    if (_selectedStatus == 'all') {
      return _myOrders;
    }
    
    return _myOrders.where((order) {
      final estimates = _orderEstimates[order.id] ?? [];
      
      switch (_selectedStatus) {
        case 'waiting':
          // 견적 대기: 견적이 아직 제출되지 않은 상태
          return estimates.isEmpty && order.status == app_models.Order.STATUS_PENDING;
        case 'bidding':
          // 입찰 내역: 견적이 제출되었지만 아직 선택되지 않은 상태
          return estimates.isNotEmpty && estimates.every((e) => !e.isAwarded);
        case 'completed':
          // 완료: 견적이 선택되어 완료된 상태
          return estimates.any((e) => e.isAwarded) || order.status == app_models.Order.STATUS_COMPLETED;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveUtils.isTablet(context);
    
    return Scaffold(
      appBar: CommonAppBar(
        title: '내 견적',
        showBackButton: true,
        showHomeButton: true,
      ),
      body: Column(
        children: [
          // 상태 필터
          _buildFilterChips(),
          
          // 견적 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadMyEstimates,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            final estimates = _orderEstimates[order.id] ?? [];
                            return _buildOrderCard(order, estimates, isTablet);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip('전체', null),
          const SizedBox(width: 8),
          _buildFilterChip('견적 대기', 'pending'),
          const SizedBox(width: 8),
          _buildFilterChip('입찰 중', 'bidding'),
          const SizedBox(width: 8),
          _buildFilterChip('완료', 'completed'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? status) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF222B45),
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? status : null;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF4F8CFF),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF4F8CFF) : Colors.grey[300]!,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildOrderCard(app_models.Order order, List<Estimate> estimates, bool isTablet) {
    final hasEstimates = estimates.isNotEmpty;
    final awardedEstimate = estimates.where((e) => e.isAwarded).firstOrNull;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 주문 정보
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '주문 ID: ${order.id.substring(0, 8)}...',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _buildOrderStatusChip(order.status),
              ],
            ),
            const SizedBox(height: 12),
            
            // 주문 상세 정보
            Text(
              order.description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.address,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '방문 희망일: ${order.visitDate.toString().split(' ')[0]}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 견적 정보
            Row(
              children: [
                Icon(Icons.assignment, size: 20, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  '견적 제안 (${estimates.length}개)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
            
            if (hasEstimates) ...[
              const SizedBox(height: 12),
              ...estimates.map((estimate) => _buildEstimateCard(estimate)),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '아직 견적 제안이 없습니다.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
            
            if (awardedEstimate != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.green[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '선택된 견적',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          Text(
                            '${awardedEstimate.technicianName} - ${awardedEstimate.formattedPrice}',
                            style: TextStyle(color: Colors.green[600]),
                          ),
                          Text(
                            '작업 기간: ${awardedEstimate.estimatedDays}일',
                            style: TextStyle(color: Colors.green[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEstimateCard(Estimate estimate) {
    return Card(
      child: InkWell(
        onTap: () => context.push('/estimate-detail'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      estimate.technicianName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF222B45),
                      ),
                    ),
                  ),
                  _buildStatusChip(estimate.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                estimate.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(estimate.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C6AE).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${estimate.price.toStringAsFixed(0)}원',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00C6AE),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderStatusChip(String status) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        statusText = '대기 중';
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case 'in_progress':
        statusText = '진행 중';
        statusColor = Colors.blue;
        statusIcon = Icons.work;
        break;
      case 'completed':
        statusText = '완료';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusText = '취소됨';
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusText = '알 수 없음';
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 14),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        statusText = '견적 대기';
        statusColor = const Color(0xFFFFA726);
        statusIcon = Icons.schedule;
        break;
      case 'bidding':
        statusText = '입찰 중';
        statusColor = const Color(0xFF4F8CFF);
        statusIcon = Icons.gavel;
        break;
      case 'completed':
        statusText = '완료';
        statusColor = const Color(0xFF00C6AE);
        statusIcon = Icons.check_circle;
        break;
      default:
        statusText = '알 수 없음';
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 14),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF4F8CFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.description_outlined,
              size: 48,
              color: const Color(0xFF4F8CFF),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '아직 견적이 없습니다',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222B45),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 견적 요청을 만들어보세요',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/create-request'),
            icon: const Icon(Icons.add),
            label: const Text('견적 요청하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F8CFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
} 