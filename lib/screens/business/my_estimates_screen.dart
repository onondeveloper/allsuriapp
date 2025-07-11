import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/estimate.dart';
import '../../services/estimate_service.dart';
import '../../services/auth_service.dart';
import 'transfer_estimate_screen.dart';

class BusinessMyEstimatesScreen extends StatefulWidget {
  const BusinessMyEstimatesScreen({super.key});

  @override
  State<BusinessMyEstimatesScreen> createState() => _BusinessMyEstimatesScreenState();
}

class _BusinessMyEstimatesScreenState extends State<BusinessMyEstimatesScreen> {
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadEstimates();
  }

  Future<void> _loadEstimates() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final estimateService = Provider.of<EstimateService>(context, listen: false);
    
    if (authService.currentUser != null) {
      await estimateService.loadEstimates(businessId: authService.currentUser!.id);
    }
  }

  List<Estimate> _getFilteredEstimates(List<Estimate> estimates) {
    if (_selectedStatus == 'all') {
      return estimates;
    }
    return estimates.where((estimate) => estimate.status == _selectedStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('내 견적'),
      ),
      child: SafeArea(
        child: Consumer<EstimateService>(
          builder: (context, estimateService, child) {
            if (estimateService.isLoading) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final filteredEstimates = _getFilteredEstimates(estimateService.estimates);

            return Column(
              children: [
                // 상태 필터
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusFilter('전체', 'all'),
                        const SizedBox(width: 8),
                        _buildStatusFilter('대기중', Estimate.STATUS_PENDING),
                        const SizedBox(width: 8),
                        _buildStatusFilter('채택됨', Estimate.STATUS_AWARDED),
                        const SizedBox(width: 8),
                        _buildStatusFilter('수락됨', Estimate.STATUS_ACCEPTED),
                        const SizedBox(width: 8),
                        _buildStatusFilter('거절됨', Estimate.STATUS_REJECTED),
                        const SizedBox(width: 8),
                        _buildStatusFilter('완료', Estimate.STATUS_COMPLETED),
                      ],
                    ),
                  ),
                ),
                
                // 견적 목록
                Expanded(
                  child: filteredEstimates.isEmpty
                      ? _buildEmptyState()
                      : CupertinoScrollbar(
                          child: CustomScrollView(
                            slivers: [
                              CupertinoSliverRefreshControl(
                                onRefresh: _loadEstimates,
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.all(16),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final estimate = filteredEstimates[index];
                                      return _buildEstimateCard(context, estimate, estimateService);
                                    },
                                    childCount: filteredEstimates.length,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusFilter(String label, String status) {
    final isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? CupertinoColors.activeBlue : CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? CupertinoColors.white : CupertinoColors.black,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = _selectedStatus == 'all' 
        ? '아직 견적이 없습니다'
        : '${_getStatusText(_selectedStatus)} 상태의 견적이 없습니다';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.doc_text,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '견적 요청을 받으면 여기에 표시됩니다',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateCard(BuildContext context, Estimate estimate, EstimateService estimateService) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator,
          width: 1,
        ),
      ),
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
                    estimate.customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.label,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(estimate.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(estimate.status),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusColor(estimate.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '견적 금액: ${estimate.amount.toStringAsFixed(0)}원',
              style: const TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '예상 소요일: ${estimate.estimatedDays}일',
              style: const TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              estimate.description,
              style: const TextStyle(
                fontSize: 14,
                color: CupertinoColors.label,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            
            // 액션 버튼들
            Row(
              children: [
                if (estimate.status == Estimate.STATUS_APPROVED) ...[
                  Expanded(
                    child: CupertinoButton.filled(
                      onPressed: () {
                        estimateService.completeEstimate(estimate.id);
                      },
                      child: const Text('완료'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (estimate.status == Estimate.STATUS_APPROVED) ...[
                  Expanded(
                    child: CupertinoButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => TransferEstimateScreen(estimate: estimate),
                          ),
                        );
                      },
                      child: const Text('이관'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case Estimate.STATUS_PENDING:
        return CupertinoColors.systemOrange;
      case Estimate.STATUS_APPROVED:
        return CupertinoColors.systemGreen;
      case Estimate.STATUS_REJECTED:
        return CupertinoColors.systemRed;
      case Estimate.STATUS_COMPLETED:
        return CupertinoColors.systemBlue;
      case Estimate.STATUS_TRANSFERRED:
        return CupertinoColors.systemPurple;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case Estimate.STATUS_PENDING:
        return '대기중';
      case Estimate.STATUS_APPROVED:
        return '승인됨';
      case Estimate.STATUS_REJECTED:
        return '거부됨';
      case Estimate.STATUS_COMPLETED:
        return '완료';
      case Estimate.STATUS_TRANSFERRED:
        return '이관됨';
      default:
        return '알 수 없음';
    }
  }
} 