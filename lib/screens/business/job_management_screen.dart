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
import 'order_review_screen.dart';

class JobManagementScreen extends StatefulWidget {
  const JobManagementScreen({super.key});

  @override
  State<JobManagementScreen> createState() => _JobManagementScreenState();
}

class _JobManagementScreenState extends State<JobManagementScreen> {
  List<Job> _combinedJobs = [];
  bool _isLoading = true;
  String _filter = 'all'; // all | mine | in_progress | call
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

      // fetch marketplace listings for all related jobs (내가 올린 것 + 받은 것)
      final jobIds = _combinedJobs
          .map((job) => job.id)
          .whereType<String>()
          .toList();

      if (jobIds.isNotEmpty) {
        final listings = await Supabase.instance.client
            .from('marketplace_listings')
            .select('id, jobid, title, bid_count, status, claimed_by')
            .inFilter('jobid', jobIds);

        _listingByJobId = {
          for (final row in listings)
            if (row['jobid'] != null)
              row['jobid'].toString(): Map<String, dynamic>.from(row),
        };
        
        print('🔍 [JobManagement] ${_listingByJobId.length}개 listing 매핑 완료');
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
                    onCompleteJob: _completeJob,
                    onReview: _openReviewScreen,
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
                    _combinedJobs.where((j) => j.ownerBusinessId == me && j.status != 'assigned').length),
                const SizedBox(width: 10),
                _buildModernChip('진행 중', 'in_progress', Icons.construction_outlined, 
                    _combinedJobs.where((j) => j.ownerBusinessId == me && j.status == 'assigned').length),
                const SizedBox(width: 10),
                _buildModernChip('받은 공사', 'call', Icons.campaign_outlined, 
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
      if (_filter == 'mine') return j.ownerBusinessId == me && j.status != 'assigned';
      if (_filter == 'in_progress') return j.ownerBusinessId == me && j.status == 'assigned';
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

  Future<void> _completeJob(Job job) async {
    // 완료 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공사 완료'),
        content: const Text('이 공사를 완료하시겠습니까?\n완료 후 오더 소유자가 확인하고 리뷰를 남길 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('완료하기'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 로딩 표시
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      final authService = context.read<AuthService>();
      final currentUserId = authService.currentUser?.id;

      if (currentUserId == null) throw Exception('로그인이 필요합니다');

      print('🔄 [JobManagement] 공사 완료 처리 시작: jobId=${job.id}');
      print('   listingByJobId: ${_listingByJobId.keys.toList()}');
      
      // marketplace_listings 찾기 (job.id로 직접 조회)
      String? listingId = _listingByJobId[job.id]?['id']?.toString();
      
      if (listingId == null && job.id != null) {
        // 직접 조회
        print('   listingId 없음, 직접 조회 시도 (jobid=${job.id})');
        final listings = await Supabase.instance.client
            .from('marketplace_listings')
            .select('id, jobid, claimed_by')
            .eq('jobid', job.id!)
            .eq('claimed_by', currentUserId); // 내가 가져간 것만
        
        print('   직접 조회 결과: ${listings.length}개');
        if (listings.isNotEmpty) {
          listingId = listings.first['id']?.toString();
          print('   직접 조회로 listingId 찾음: $listingId');
        } else {
          print('   ❌ 직접 조회 실패 - claimed_by로 조회해도 없음');
        }
      }
      
      if (listingId != null) {
        print('   marketplace_listings 업데이트 중: $listingId');
        await Supabase.instance.client
            .from('marketplace_listings')
            .update({
              'status': 'completed',
              'completed_at': DateTime.now().toIso8601String(),
              'completed_by': currentUserId,
              'updatedat': DateTime.now().toIso8601String(),
            })
            .eq('id', listingId);

        // 오더 소유자에게 알림
        final ownerId = job.ownerBusinessId;
        print('   알림 전송 중: $ownerId');
        await Supabase.instance.client.from('notifications').insert({
          'userid': ownerId,
          'title': '공사 완료',
          'body': '${job.title} 공사가 완료되었습니다. 리뷰를 남겨주세요!',
          'type': 'order_completed',
          'jobid': listingId,
          'isread': false,
          'createdat': DateTime.now().toIso8601String(),
        });

        print('✅ [JobManagement] 공사 완료 처리 완료');
      } else {
        print('⚠️ [JobManagement] listingId를 찾을 수 없음');
      }

      // jobs 테이블도 업데이트
      if (job.id != null) {
        print('   jobs 테이블 업데이트 중');
        await Supabase.instance.client
            .from('jobs')
            .update({
              'status': 'completed',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', job.id!);
      }

      if (mounted) {
        Navigator.pop(context); // 로딩 닫기
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('공사가 완료되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        
        await _loadJobs(); // 목록 새로고침
      }
    } catch (e) {
      print('❌ [JobManagement] 공사 완료 실패: $e');
      
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop(); // 로딩 닫기
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('공사 완료 처리 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openReviewScreen(Job job) async {
    final listing = _listingByJobId[job.id];
    if (listing == null) return;
    
    final listingId = listing['id']?.toString() ?? '';
    final revieweeId = job.assignedBusinessId ?? '';
    
    if (listingId.isEmpty || revieweeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리뷰를 작성할 수 없습니다')),
      );
      return;
    }

    // 리뷰 대상 사업자 이름 가져오기
    try {
      final user = await Supabase.instance.client
          .from('users')
          .select('businessname, name')
          .eq('id', revieweeId)
          .maybeSingle();
      
      final revieweeName = user?['businessname'] ?? user?['name'] ?? '사업자';

      if (!mounted) return;

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OrderReviewScreen(
            listingId: listingId,
            jobId: job.id ?? '',
            revieweeId: revieweeId,
            revieweeName: revieweeName,
            orderTitle: job.title,
          ),
        ),
      );

      if (result == true) {
        await _loadJobs();
      }
    } catch (e) {
      print('❌ [JobManagement] 리뷰 화면 열기 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리뷰 화면을 열 수 없습니다')),
      );
    }
  }
}

class _ModernJobsList extends StatelessWidget {
  final List<Job> jobs;
  final String currentUserId;
  final Map<String, Map<String, dynamic>> listingsByJobId;
  final void Function(String listingId, String orderTitle) onViewBidders;
  final Future<void> Function(Job job) onCompleteJob;
  final Future<void> Function(Job job) onReview;

  const _ModernJobsList({
    required this.jobs,
    required this.currentUserId,
    required this.listingsByJobId,
    required this.onViewBidders,
    required this.onCompleteJob,
    required this.onReview,
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
                // 받은 공사 완료 버튼 (assignedBusinessId == currentUserId)
                if (job.assignedBusinessId == currentUserId && job.status == 'assigned') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => onCompleteJob(job),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('공사 완료', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                // 진행 중(assigned) 오더 리뷰 버튼 (ownerBusinessId == currentUserId && status == 'completed')
                if (job.ownerBusinessId == currentUserId && 
                    job.status == 'completed' && 
                    listing != null && 
                    listing['status'] == 'completed') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => onReview(job),
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: const Text('리뷰 작성', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
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


