import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../services/payment_service.dart';

class AcceptTransferScreen extends StatefulWidget {
  final String jobId;
  const AcceptTransferScreen({super.key, required this.jobId});

  @override
  State<AcceptTransferScreen> createState() => _AcceptTransferScreenState();
}

class _AcceptTransferScreenState extends State<AcceptTransferScreen> {
  final TextEditingController _awardedAmountController = TextEditingController();
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이관 수락 및 결제')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data();
          if (data == null) return const Center(child: Text('공사 정보를 불러올 수 없습니다'));
          final title = data['title'] ?? '공사';
          final desc = data['description'] ?? '';
          final ownerId = data['ownerBusinessId'] ?? '';
          final transferTo = data['transferToBusinessId'] ?? '';
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(desc, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),
                TextField(
                  controller: _awardedAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '낙찰 금액',
                    prefixText: '₩ ',
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _processing
                        ? null
                        : () async {
                            final assigneeId = context.read<AuthService>().currentUser?.id;
                            if (assigneeId == null) return;
                            final awarded = double.tryParse(_awardedAmountController.text.replaceAll(',', ''));
                            if (awarded == null) return;
                            setState(() => _processing = true);
                            try {
                              final ok = await context.read<PaymentService>().chargeTransferFee(
                                    payerBusinessId: assigneeId,
                                    payeeBusinessId: ownerId,
                                    awardedAmount: awarded,
                                  );
                              if (!ok) return;
                              await context.read<JobService>().acceptTransfer(
                                    jobId: widget.jobId,
                                    assigneeBusinessId: assigneeId,
                                    awardedAmount: awarded,
                                  );
                              // B2B 플랫폼 3% 정산 가상 알림
                              await context.read<PaymentService>().notifyB2bPlatformFee(
                                    assigneeBusinessId: assigneeId,
                                    awardedAmount: awarded,
                                  );
                              if (!mounted) return;
                              Navigator.pop(context);
                            } finally {
                              if (mounted) setState(() => _processing = false);
                            }
                          },
                    child: _processing
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('즉시 결제 후 수락'),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}


