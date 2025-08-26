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
      appBar: AppBar(
        title: const Text('공사 관리'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: _isLoading
          ? const ShimmerList(itemCount: 6, itemHeight: 120)
          : Column(
              children: [
                _buildFilterChips(),
                Expanded(
                  child: _UnifiedJobsList(
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

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _chip('전체', 'all'),
          const SizedBox(width: 8),
          _chip('내 공사', 'mine'),
          const SizedBox(width: 8),
          _chip('이관 요청', 'transfer'),
          const SizedBox(width: 8),
          _chip('콜 공사', 'call'),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
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

class _UnifiedJobsList extends StatelessWidget {
  final List<Job> jobs;
  final String currentUserId;
  final void Function(Job) onTransfer;
  final void Function(Job) onAcceptTransfer;

  const _UnifiedJobsList({
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
            Icon(
              Icons.work_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '표시할 공사가 없습니다.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final job = jobs[index];
        final badge = _badgeFor(job, currentUserId);
        return Stack(
          children: [
            InteractiveCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Text(
                      job.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    // 지역
                    if (job.location != null && job.location!.isNotEmpty)
                      Text(
                        '지역: ${job.location!}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 6),
                    // 내용
                    Text(
                      job.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 수수료
                    if (job.commissionRate != null && job.budgetAmount != null)
                      Text(
                        '수수료: ${(job.budgetAmount! * (job.commissionRate! / 100)).toStringAsFixed(0)}원 (${job.commissionRate!.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    // 상태칩
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(job.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(job.status),
                            style: TextStyle(
                              color: _getStatusColor(job.status),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (job.ownerBusinessId == currentUserId && job.status != 'pending_transfer')
                          OutlinedButton.icon(
                            onPressed: () => onTransfer(job),
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('이관'),
                          ),
                        if (job.assignedBusinessId == currentUserId && job.status == 'assigned') ...[
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () async {
                              final ok = await MarketplaceService().withdrawClaimForJob(job.id ?? '');
                              if (!context.mounted) return;
                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('콜 공사를 취소했습니다.')),
                                );
                                (context.findAncestorStateOfType<_JobManagementScreenState>())?._loadJobs();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('취소에 실패했습니다.')),
                                );
                              }
                            },
                            child: const Text('취소'),
                          ),
                        ],
                        if (job.transferToBusinessId == currentUserId && job.status == 'pending_transfer') ...[
                          const SizedBox(width: 12),
                          FilledButton.tonal(
                            onPressed: () => onAcceptTransfer(job),
                            child: const Text('수락'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 우측 상단 배지 (메인) + 카테고리 배지 함께 표시
            Positioned(
              top: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: badge.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: badge.color),
                    ),
                    child: Text(
                      badge.label,
                      style: TextStyle(color: badge.color, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (job.category != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.4)),
                      ),
                      child: Text(
                        job.category!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  _Badge _badgeFor(Job job, String me) {
    if (job.assignedBusinessId == me) {
      return _Badge('콜 공사', Colors.green);
    }
    if (job.transferToBusinessId == me && job.status == 'pending_transfer') {
      return _Badge('이관 요청', Colors.orange);
    }
    if (job.ownerBusinessId == me) {
      return _Badge('내 공사', Colors.blue);
    }
    return _Badge('공사', Colors.grey);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'created':
        return Colors.blue;
      case 'pending_transfer':
        return Colors.orange;
      case 'assigned':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'created':
        return '등록됨';
      case 'pending_transfer':
        return '이관 대기';
      case 'assigned':
        return '이관 완료';
      case 'completed':
        return '완료';
      case 'cancelled':
        return '취소됨';
      default:
        return status;
    }
  }
}

class _Badge {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
}


