import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/job.dart';
import 'transfer_job_screen.dart';
import 'accept_transfer_screen.dart';

class JobManagementScreen extends StatefulWidget {
  const JobManagementScreen({super.key});

  @override
  State<JobManagementScreen> createState() => _JobManagementScreenState();
}

class _JobManagementScreenState extends State<JobManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthService>().currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('공사 관리'),
        bottom: const TabBar(
          tabs: [
            Tab(text: '내 공사'),
            Tab(text: '이관 요청'),
            Tab(text: '배정됨'),
          ],
        ),
      ),
      body: DefaultTabController(
        length: 3,
        initialIndex: 0,
        child: TabBarView(
          controller: _tabController,
          children: [
            _JobsList(
              query: FirebaseFirestore.instance
                  .collection('jobs')
                  .where('ownerBusinessId', isEqualTo: currentUserId)
                  .orderBy('createdAt', descending: true),
              trailingBuilder: (context, job) => TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransferJobScreen(jobId: job.id),
                    ),
                  );
                },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('이관'),
              ),
            ),
            _JobsList(
              query: FirebaseFirestore.instance
                  .collection('jobs')
                  .where('transferToBusinessId', isEqualTo: currentUserId)
                  .where('status', isEqualTo: 'pending_transfer')
                  .orderBy('createdAt', descending: true),
              trailingBuilder: (context, job) => FilledButton.tonal(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AcceptTransferScreen(jobId: job.id),
                    ),
                  );
                },
                child: const Text('수락'),
              ),
            ),
            _JobsList(
              query: FirebaseFirestore.instance
                  .collection('jobs')
                  .where('assignedBusinessId', isEqualTo: currentUserId)
                  .orderBy('createdAt', descending: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobsList extends StatelessWidget {
  final Query<Map<String, dynamic>> query;
  final Widget Function(BuildContext, Job)? trailingBuilder;

  const _JobsList({
    required this.query,
    this.trailingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('표시할 공사가 없습니다.'));
        }
        final jobs = snapshot.data!.docs
            .map((doc) => Job.fromMap(doc.data(), doc.id))
            .toList();
        return ListView.separated(
          itemCount: jobs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final job = jobs[index];
            return ListTile(
              title: Text(job.title),
              subtitle: Text('${job.status} • ${job.description}'),
              trailing: trailingBuilder?.call(context, job),
            );
          },
        );
      },
    );
  }
}


