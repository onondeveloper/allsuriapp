import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../services/marketplace_service.dart';
import '../../models/job.dart';
import '../../widgets/interactive_card.dart';
import 'transfer_job_screen.dart';

class JobManagementScreen extends StatefulWidget {
  const JobManagementScreen({super.key});

  @override
  State<JobManagementScreen> createState() => _JobManagementScreenState();
}

class _JobManagementScreenState extends State<JobManagementScreen> {
  List<Job> _combinedJobs = [];
  bool _isLoading = true;
  String _filter = 'all'; // all | mine | transfer | call

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    
    try {
      final authService = context.read<AuthService>();
      final jobService = context.read<JobService>();
      final currentUserId = authService.currentUser?.id;
      
      if (currentUserId == null) return;

      final allJobs = await jobService.getJobs();
      final related = allJobs.where((job) =>
          job.ownerBusinessId == currentUserId ||
          job.transferToBusinessId == currentUserId ||
          job.assignedBusinessId == currentUserId).toList();
      final Map<String, Job> byId = {};
      for (final j in related) {
        final id = j.id ?? UniqueKey().toString();
        byId[id] = j;
      }
      _combinedJobs = byId.values.toList();
      _combinedJobs.sort((a, b) {
        final me = currentUserId;
        int score(Job j) {
          final transferCompleted = (j.ownerBusinessId == me && j.status == 'assigned' && j.assignedBusinessId != me) ? 1 : 0;
          return transferCompleted; // 0 먼저, 1(이관 완료) 나중
        }
        final s = score(a).compareTo(score(b));
        if (s != 0) return s;
        return 0;
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공사 목록을 불러오는데 실패했습니다: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('내 공사', style: TextStyle(fontWeight: FontWeight.w600)),
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
            onPressed: _loadJobs,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? const ShimmerList(itemCount: 6, itemHeight: 120)
          : Column(
              children: [
                _buildModernFilterChips(),
                Expanded(
                  child: _ModernJobsList(
                    jobs: _filteredByBadge(_combinedJobs, context.read<AuthService>().currentUser?.id ?? ''),
                    currentUserId: context.read<AuthService>().currentUser?.id ?? '',
                    onTransfer: _showTransferDialog,
                    onAcceptTransfer: _showAcceptTransferDialog,
                  ),
                ),
              ],
            ),
    );
  }

  void _showCheck() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'check',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) {
        return Center(
          child: SizedBox(width: 140, height: 140, child: Lottie.asset('assets/lottie/check.json', repeat: false)),
        );
      },
    );
    Future.delayed(const Duration(milliseconds: 900), () {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  Widget _buildModernFilterChips() {
    final me = context.read<AuthService>().currentUser?.id ?? '';
    
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '필터',
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
                _buildModernChip('전체', 'all', Icons.dashboard_outlined, _combinedJobs.length),
                const SizedBox(width: 10),
                _buildModernChip('내 공사', 'mine', Icons.person_outline, 
                    _combinedJobs.where((j) => j.ownerBusinessId == me).length),
                const SizedBox(width: 10),
                _buildModernChip('이관 요청', 'transfer', Icons.swap_horiz_rounded, 
                    _combinedJobs.where((j) => j.transferToBusinessId == me && j.status == 'pending_transfer').length),
                const SizedBox(width: 10),
                _buildModernChip('콜 공사', 'call', Icons.campaign_outlined, 
                    _combinedJobs.where((j) => j.assignedBusinessId == me).length),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernChip(String label, String value, IconData icon, int count) {
    final isSelected = _filter == value;
    final color = const Color(0xFFF9A825); // Yellow for jobs
    
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
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
              color: isSelected ? Colors.white : color,
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
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.3) : color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Job> _filteredByBadge(List<Job> jobs, String me) {
    if (_filter == 'all') return jobs;
    return jobs.where((j) {
      if (_filter == 'mine') return j.ownerBusinessId == me;
      if (_filter == 'transfer') return j.transferToBusinessId == me && j.status == 'pending_transfer';
      if (_filter == 'call') return j.assignedBusinessId == me;
      return true;
    }).toList();
  }

  void _showTransferDialog(Job job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공사 이관'),
        content: const Text('이 공사를 다른 사업자에게 이관하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransferJobScreen(jobId: job.id ?? ''),
                ),
              );
            },
            child: const Text('이관'),
          ),
        ],
      ),
    );
  }

  void _showAcceptTransferDialog(Job job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공사 수락'),
        content: const Text('이 공사를 담당하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<JobService>().acceptTransfer(
                  jobId: job.id ?? '',
                  assigneeBusinessId: context.read<AuthService>().currentUser!.id,
                  awardedAmount: job.awardedAmount ?? 0,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('공사를 받았습니다.')),
                );
                _showCheck();
                _loadJobs();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('수락 실패: $e')),
                );
              }
            },
            child: const Text('수락'),
          ),
        ],
      ),
    );
  }
}

class _ModernJobsList extends StatelessWidget {
  final List<Job> jobs;
  final String currentUserId;
  final void Function(Job) onTransfer;
  final void Function(Job) onAcceptTransfer;

  const _ModernJobsList({
    required this.jobs,
    required this.currentUserId,
    required this.onTransfer,
    required this.onAcceptTransfer,
  });

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.yellow[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.construction_outlined,
                size: 50,
                color: Colors.yellow[700],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '공사가 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Call 공사를 잡거나 새로 등록해보세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final job = jobs[index];
        final badge = _badgeFor(job, currentUserId);
        return Container(
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badge.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badge.icon, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            badge.label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Budget
                    if (job.budgetAmount != null)
                      Text(
                        '₩${job.budgetAmount!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF9A825),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  job.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                // Description
                Text(
                  job.description,
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
                    if (job.location != null && job.location!.isNotEmpty)
                      _buildInfoChip(Icons.location_on_outlined, job.location!),
                    if (job.category != null && job.category!.isNotEmpty)
                      _buildInfoChip(Icons.category_outlined, job.category!),
                    if (job.commissionRate != null)
                      _buildInfoChip(Icons.percent_rounded, '수수료 ${job.commissionRate!.toStringAsFixed(1)}%'),
                  ],
                ),
                // Action buttons
                if (badge.actionLabel.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (badge.actionLabel == '이관하기') {
                          onTransfer(job);
                        } else if (badge.actionLabel == '수락하기') {
                          onAcceptTransfer(job);
                        }
                      },
                      icon: Icon(
                        badge.actionLabel == '이관하기' ? Icons.swap_horiz_rounded : Icons.check_circle_outline,
                        size: 18,
                      ),
                      label: Text(badge.actionLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: badge.color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  static _Badge _badgeFor(Job job, String me) {
    if (job.assignedBusinessId == me) {
      return _Badge('콜 공사', Colors.green, Icons.campaign_outlined, '');
    }
    if (job.transferToBusinessId == me && job.status == 'pending_transfer') {
      return _Badge('이관 요청', Colors.orange, Icons.swap_horiz_rounded, '수락하기');
    }
    if (job.ownerBusinessId == me) {
      return _Badge('내 공사', const Color(0xFF1976D2), Icons.person_outline, '이관하기');
    }
    return _Badge('공사', Colors.grey, Icons.work_outline, '');
  }
}

class _Badge {
  final String label;
  final Color color;
  final IconData icon;
  final String actionLabel;
  
  const _Badge(this.label, this.color, this.icon, this.actionLabel);
}


