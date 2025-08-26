import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/job_service.dart';
import '../../services/auth_service.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransferJobScreen extends StatefulWidget {
  final String jobId;
  const TransferJobScreen({super.key, required this.jobId});

  @override
  State<TransferJobScreen> createState() => _TransferJobScreenState();
}

class _TransferJobScreenState extends State<TransferJobScreen> {
  String? _selectedBusinessId;
  String _query = '';
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
                onChanged: (text) => setState(() { _query = text; }),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _searchBusinesses(_query),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = snapshot.data!;
                  if (rows.isEmpty) {
                    return const Center(child: Text('검색된 사업자가 없습니다.'));
                  }
                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data = rows[index];
                      final businessId = data['id'] as String;
                      final name = (data['businessName'] ?? data['name'] ?? '사업자').toString();
                      final phone = (data['phoneNumber'] ?? data['phonenumber'] ?? '').toString();
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
                            final me = context.read<AuthService>().currentUser;
                            if (me == null) return;
                            await context.read<JobService>().requestTransfer(
                                  jobId: widget.jobId,
                                  transferToBusinessId: _selectedBusinessId!,
                                );
                            if (!mounted) return;
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
                            await Future.delayed(const Duration(milliseconds: 900));
                            if (mounted) Navigator.pop(context); // close lottie
                            if (mounted) Navigator.pop(context); // close screen
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

  Future<List<Map<String, dynamic>>> _searchBusinesses(String q) async {
    final sb = Supabase.instance.client;
    var query = sb.from('users').select('id, name, businessName, phoneNumber, phonenumber').eq('role', 'business');
    if (q.trim().isNotEmpty) {
      final like = '%${q.trim()}%';
      query = query.or('businessName.ilike.$like,name.ilike.$like,phoneNumber.ilike.$like,phonenumber.ilike.$like');
    }
    final rows = await query.limit(50);
    return rows.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
  }
}


