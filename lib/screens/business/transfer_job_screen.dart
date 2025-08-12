import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/job_service.dart';

class TransferJobScreen extends StatefulWidget {
  final String jobId;
  const TransferJobScreen({super.key, required this.jobId});

  @override
  State<TransferJobScreen> createState() => _TransferJobScreenState();
}

class _TransferJobScreenState extends State<TransferJobScreen> {
  String? _selectedBusinessId;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공사 이관')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: '상호명 또는 전화번호로 검색',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (text) => setState(() {}),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'business')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('사업자가 없습니다.'));
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final businessId = docs[index].id;
                      final name = data['businessName'] ?? data['name'] ?? '사업자';
                      final phone = data['phoneNumber'] ?? '';
                      return RadioListTile<String>(
                        value: businessId,
                        groupValue: _selectedBusinessId,
                        onChanged: (v) => setState(() => _selectedBusinessId = v),
                        title: Text(name),
                        subtitle: phone.isEmpty ? null : Text(phone),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_selectedBusinessId == null || _submitting)
                      ? null
                      : () async {
                          setState(() => _submitting = true);
                          try {
                            await context.read<JobService>().requestTransfer(
                                  jobId: widget.jobId,
                                  transferToBusinessId: _selectedBusinessId!,
                                );
                            if (!mounted) return;
                            Navigator.pop(context);
                          } finally {
                            if (mounted) setState(() => _submitting = false);
                          }
                        },
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('이관'),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}


