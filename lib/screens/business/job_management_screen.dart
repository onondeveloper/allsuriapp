import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/shimmer_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../models/job.dart';
import '../../widgets/interactive_card.dart';
import 'order_bidders_screen.dart';

class JobManagementScreen extends StatefulWidget {
  const JobManagementScreen({super.key});

  @override
  State<JobManagementScreen> createState() => _JobManagementScreenState();
}

class _JobManagementScreenState extends State<JobManagementScreen> {
  List<Job> _combinedJobs = [];
  bool _isLoading = true;
  String _filter = 'all'; // all | mine | call
  Map<String, Map<String, dynamic>> _listingByJobId = {};

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
          job.assignedBusinessId == currentUserId).toList();
      final Map<String, Job> byId = {};
      for (final j in related) {
        final id = j.id ?? UniqueKey().toString();
        byId[id] = j;
      }
      _combinedJobs = byId.values.toList();

      // fetch marketplace listings for jobs I own
      final jobIds = _combinedJobs
          .where((job) => job.ownerBusinessId == currentUserId)
          .map((job) => job.id)
          .whereType<String>()
          .toList();

      if (jobIds.isNotEmpty) {
        final listings = await Supabase.instance.client
            .from('marketplace_listings')
            .select('id, jobid, title, bid_count, status')
            .inFilter('jobid', jobIds);

        _listingByJobId = {
          for (final row in listings)
            if (row['jobid'] != null)
              row['jobid'].toString(): Map<String, dynamic>.from(row),
        };
      } else {
        _listingByJobId = {};
      }
      
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
                    listingsByJobId: _listingByJobId,
                    onViewBidders: _openBidderList,
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
      if (_filter == 'call') return j.assignedBusinessId == me;
      return true;
    }).toList();
  }

  void _openBidderList(String listingId, String orderTitle) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderBiddersScreen(
          listingId: listingId,
          orderTitle: orderTitle,
        ),
      ),
    );
    
    // 입찰자가 선택되었으면 목록 새로고침
    if (result == true) {
      print('🔄 [JobManagement] 입찰자 선택 완료, 목록 새로고침');
      await _loadJobs();
    }
  }
}

class _ModernJobsList extends StatelessWidget {
  final List<Job> jobs;
  final String currentUserId;
  final Map<String, Map<String, dynamic>> listingsByJobId;
  final void Function(String listingId, String orderTitle) onViewBidders;

  const _ModernJobsList({
    required this.jobs,
    required this.currentUserId,
    required this.listingsByJobId,
    required this.onViewBidders,
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
        final listing = job.id != null ? listingsByJobId[job.id] : null;
        final listingId = listing != null ? listing['id']?.toString() : null;
        final listingTitle = listing != null ? (listing['title']?.toString() ?? job.title) : job.title;
        final bidCount = listing != null
            ? (listing['bid_count'] is int
                ? listing['bid_count'] as int
                : int.tryParse(listing['bid_count']?.toString() ?? '0') ?? 0)
            : 0;
        final canViewBidders = job.ownerBusinessId == currentUserId && listingId != null;
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
                if (canViewBidders) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => onViewBidders(listingId!, listingTitle),
                      icon: const Icon(Icons.people_outline, size: 18),
                      label: Text('입찰자 보기 (${bidCount}명)', style: const TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
      return _Badge('콜 공사', Colors.green, Icons.campaign_outlined);
    }
    if (job.ownerBusinessId == me) {
      return _Badge('내 공사', const Color(0xFF1976D2), Icons.person_outline);
    }
    return _Badge('공사', Colors.grey, Icons.work_outline);
  }
}

class _Badge {
  final String label;
  final Color color;
  final IconData icon;
  
  const _Badge(this.label, this.color, this.icon);
}


