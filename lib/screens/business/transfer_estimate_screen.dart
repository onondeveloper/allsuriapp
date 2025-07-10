import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../models/role.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../order/create_order_screen.dart';
import '../../models/estimate.dart';
import '../../services/services.dart';
import '../../widgets/common_app_bar.dart';
import '../../utils/responsive_utils.dart';
import 'package:go_router/go_router.dart';

class TransferEstimateScreen extends StatefulWidget {
  final Estimate estimate;
  
  const TransferEstimateScreen({
    Key? key,
    required this.estimate,
  }) : super(key: key);

  @override
  State<TransferEstimateScreen> createState() => _TransferEstimateScreenState();
}

class _TransferEstimateScreenState extends State<TransferEstimateScreen> {
  final _searchController = TextEditingController();
  List<User> _searchResults = [];
  List<User> _allBusinessUsers = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadBusinessUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadBusinessUsers();
      _allBusinessUsers = userProvider.businessUsers;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사업자 목록을 불러오는 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _searchBusinessUsers(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = _allBusinessUsers.where((user) {
        final searchQuery = query.toLowerCase();
        return user.name.toLowerCase().contains(searchQuery) ||
               (user.businessName?.toLowerCase().contains(searchQuery) ?? false) ||
               (user.phoneNumber?.contains(searchQuery) ?? false);
      }).toList();
    });
  }

  Future<void> _transferEstimate(User targetBusiness) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final estimateService = Provider.of<EstimateService>(context, listen: false);
      
      // 이관 견적 생성
      final transferEstimate = Estimate(
        id: 'TRANSFER_${DateTime.now().millisecondsSinceEpoch}',
        orderId: widget.estimate.orderId,
        technicianId: targetBusiness.id,
        technicianName: targetBusiness.displayName,
        price: widget.estimate.price,
        description: widget.estimate.description,
        estimatedDays: widget.estimate.estimatedDays,
        status: Estimate.STATUS_PENDING,
        createdAt: DateTime.now(),
        visitDate: widget.estimate.visitDate,
        customerName: widget.estimate.customerName,
        customerPhone: widget.estimate.customerPhone,
        address: widget.estimate.address,
        isTransferEstimate: true,
        isAwarded: false,
        awardedAt: null,
        awardedBy: null,
      );

      await estimateService.createEstimate(transferEstimate);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${targetBusiness.displayName}에게 견적을 이관했습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('견적 이관 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showTransferConfirmation(User targetBusiness) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('견적 이관 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${targetBusiness.displayName}에게 견적을 이관하시겠습니까?'),
            const SizedBox(height: 16),
            Text('견적 금액: ${widget.estimate.price.toStringAsFixed(0)}원'),
            const SizedBox(height: 8),
            Text('설명: ${widget.estimate.description}'),
            const SizedBox(height: 16),
            const Text(
              '※ 이관된 견적은 수수료가 발생할 수 있습니다.',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _transferEstimate(targetBusiness);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F8CFF),
            ),
            child: const Text('이관하기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '견적 이관하기',
        showBackButton: true,
        showHomeButton: true,
      ),
      body: Column(
        children: [
          // 검색 영역
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '사업자 검색',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222B45),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '사업자명, 상호명, 전화번호로 검색',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchBusinessUsers('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _searchBusinessUsers,
                ),
              ],
            ),
          ),

          // 검색 결과 또는 전체 사업자 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildBusinessList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessList() {
    final displayList = _isSearching ? _searchResults : _allBusinessUsers;
    
    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSearching ? Icons.search_off : Icons.business,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching ? '검색 결과가 없습니다.' : '등록된 사업자가 없습니다.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final business = displayList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF4F8CFF).withOpacity(0.1),
              child: Icon(
                Icons.business,
                color: const Color(0xFF4F8CFF),
              ),
            ),
            title: Text(
              business.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (business.phoneNumber != null) ...[
                  Text('전화번호: ${business.phoneNumber}'),
                  const SizedBox(height: 4),
                ],
                if (business.serviceAreas.isNotEmpty) ...[
                  Text('활동지역: ${business.serviceAreas.join(', ')}'),
                  const SizedBox(height: 4),
                ],
                if (business.specialties.isNotEmpty) ...[
                  Text('전문분야: ${business.specialties.join(', ')}'),
                ],
              ],
            ),
            trailing: ElevatedButton(
              onPressed: () => _showTransferConfirmation(business),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F8CFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('이관하기'),
            ),
          ),
        );
      },
    );
  }
}
