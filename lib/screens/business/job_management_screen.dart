import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../models/job.dart';
import '../../widgets/interactive_card.dart';

class JobManagementScreen extends StatefulWidget {
  const JobManagementScreen({super.key});

  @override
  State<JobManagementScreen> createState() => _JobManagementScreenState();
}

class _JobManagementScreenState extends State<JobManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Job> _myJobs = [];
  List<Job> _pendingTransfers = [];
  List<Job> _assignedJobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadJobs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    
    try {
      final authService = context.read<AuthService>();
      final jobService = context.read<JobService>();
      final currentUserId = authService.currentUser?.id;
      
      if (currentUserId == null) return;

      // 내가 등록한 공사들
      _myJobs = await jobService.getBusinessJobs(currentUserId);
      
      // 이관 요청받은 공사들
      final allJobs = await jobService.getJobs();
      _pendingTransfers = allJobs.where((job) => 
        job.transferToBusinessId == currentUserId && 
        job.status == 'pending_transfer'
      ).toList();
      
      // 내가 담당하는 공사들
      _assignedJobs = allJobs.where((job) => 
        job.assignedBusinessId == currentUserId
      ).toList();
      
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '내 공사'),
            Tab(text: '이관 요청'),
            Tab(text: '담당 공사'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _JobsList(
                  jobs: _myJobs,
                  emptyMessage: '등록된 공사가 없습니다.',
                  trailingBuilder: (context, job) => TextButton.icon(
                    onPressed: () => _showTransferDialog(job),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('이관'),
                  ),
                ),
                _JobsList(
                  jobs: _pendingTransfers,
                  emptyMessage: '이관 요청받은 공사가 없습니다.',
                  trailingBuilder: (context, job) => FilledButton.tonal(
                    onPressed: () => _showAcceptTransferDialog(job),
                    child: const Text('수락'),
                  ),
                ),
                _JobsList(
                  jobs: _assignedJobs,
                  emptyMessage: '담당하는 공사가 없습니다.',
                ),
              ],
            ),
    );
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
              // TODO: 이관할 사업자 선택 화면으로 이동
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('이관 기능은 준비 중입니다.')),
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
            onPressed: () {
              Navigator.pop(context);
              // TODO: 공사 수락 처리
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('수락 기능은 준비 중입니다.')),
              );
            },
            child: const Text('수락'),
          ),
        ],
      ),
    );
  }
}

class _JobsList extends StatelessWidget {
  final List<Job> jobs;
  final String emptyMessage;
  final Widget Function(BuildContext, Job)? trailingBuilder;

  const _JobsList({
    required this.jobs,
    required this.emptyMessage,
    this.trailingBuilder,
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
              emptyMessage,
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
        return InteractiveCard(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              job.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  job.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
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
                    if (job.category != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          job.category!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (job.budgetAmount != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '예산: ${job.budgetAmount!.toStringAsFixed(0)}원',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            trailing: trailingBuilder?.call(context, job),
          ),
        );
      },
    );
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
        return '담당됨';
      case 'completed':
        return '완료';
      case 'cancelled':
        return '취소됨';
      default:
        return status;
    }
  }
}


