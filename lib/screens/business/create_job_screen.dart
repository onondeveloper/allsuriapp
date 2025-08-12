import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';

class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({super.key});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공사 만들기')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '공사 제목'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력하세요' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '상세 설명'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '설명을 입력하세요' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '예산 (선택)'),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) return;
                            setState(() => _submitting = true);
                            final auth = context.read<AuthService>();
                            final jobService = context.read<JobService>();
                            final ownerId = auth.currentUser?.id;
                            if (ownerId == null) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('로그인이 필요합니다.')));
                              setState(() => _submitting = false);
                              return;
                            }
                            final double? budget = _budgetController.text.trim().isEmpty
                                ? null
                                : double.tryParse(_budgetController.text.replaceAll(',', ''));
                            await jobService.createJob(
                              ownerBusinessId: ownerId,
                              title: _titleController.text.trim(),
                              description: _descController.text.trim(),
                              budgetAmount: budget,
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                          },
                    child: _submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('등록'),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}


