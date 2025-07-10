import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/estimate.dart';
import '../../providers/estimate_provider.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/estimate_list_item.dart';
import 'package:go_router/go_router.dart';

class TransferredEstimatesScreen extends StatefulWidget {
  const TransferredEstimatesScreen({Key? key}) : super(key: key);

  @override
  State<TransferredEstimatesScreen> createState() => _TransferredEstimatesScreenState();
}

class _TransferredEstimatesScreenState extends State<TransferredEstimatesScreen> {
  String _selectedStatus = 'All';
  bool _isLoading = false;

  final List<String> _statusFilters = [
    'All',
    'Pending',
    'Accepted',
    'Rejected',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _loadTransferredEstimates();
  }

  Future<void> _loadTransferredEstimates() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final estimateProvider = Provider.of<EstimateProvider>(context, listen: false);
      await estimateProvider.loadTransferredEstimates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('견적 목록을 불러오는 중 오류가 발생했습니다: $e'),
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

  List<Estimate> _getFilteredEstimates(List<Estimate> estimates) {
    if (_selectedStatus == 'All') {
      return estimates;
    }
    
    return estimates.where((estimate) {
      switch (_selectedStatus) {
        case 'Pending':
          return estimate.status == Estimate.STATUS_PENDING;
        case 'Accepted':
          return estimate.status == Estimate.STATUS_ACCEPTED;
        case 'Rejected':
          return estimate.status == Estimate.STATUS_REJECTED;
        case 'Completed':
          return estimate.status == Estimate.STATUS_AWARDED;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '이관한 견적',
        showBackButton: true,
        showHomeButton: true,
      ),
      body: Column(
        children: [
          // 상태 필터
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '상태별 필터',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222B45),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusFilters.map((status) {
                      final isSelected = _selectedStatus == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_getStatusLabel(status)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _isLoading = true;
                            });
                            setState(() {
                              _selectedStatus = status;
                              _isLoading = false;
                            });
                          },
                          backgroundColor: Colors.grey.shade200,
                          selectedColor: const Color(0xFF4F8CFF),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 견적 목록
          Expanded(
            child: Consumer<EstimateProvider>(
              builder: (context, estimateProvider, child) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final transferredEstimates = estimateProvider.transferredEstimates;
                final filteredEstimates = _getFilteredEstimates(transferredEstimates);

                if (filteredEstimates.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.transfer_within_a_station,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          transferredEstimates.isEmpty
                              ? '이관한 견적이 없습니다.'
                              : '선택한 상태의 견적이 없습니다.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '다른 사업자에게 견적을 이관하면\n여기에 표시됩니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadTransferredEstimates,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredEstimates.length,
                    itemBuilder: (context, index) {
                      final estimate = filteredEstimates[index];
                      return EstimateListItem(
                        estimate: estimate,
                        onTap: () {
                          // 견적 상세 화면으로 이동
                          context.push('/estimate-detail/${estimate.id}');
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'All':
        return '전체';
      case 'Pending':
        return '대기중';
      case 'Accepted':
        return '수락됨';
      case 'Rejected':
        return '거절됨';
      case 'Completed':
        return '완료';
      default:
        return status;
    }
  }
} 