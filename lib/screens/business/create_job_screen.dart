import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../widgets/interactive_card.dart';

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
  final TextEditingController _locationController = TextEditingController();
  
  String _selectedCategory = '일반';
  String _selectedUrgency = 'normal';
  bool _submitting = false;

  final List<String> _categories = [
    '일반', '전기', '수도', '난방', '에어컨', '인테리어', '청소', '기타'
  ];

  final Map<String, String> _urgencyLabels = {
    'low': '낮음',
    'normal': '보통',
    'high': '높음',
    'urgent': '긴급'
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _submitting = true);
    
    try {
      final auth = context.read<AuthService>();
      final jobService = context.read<JobService>();
      final ownerId = auth.currentUser?.id;
      
      if (ownerId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.'))
        );
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
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        category: _selectedCategory,
        urgency: _selectedUrgency,
        commissionRate: 5.0, // Default 5% commission
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공사가 성공적으로 등록되었습니다!'))
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('공사 등록에 실패했습니다: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('공사 만들기'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 공사 제목
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '공사 제목 *',
                  hintText: '예: 아파트 누수 공사',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력하세요' : null,
              ),
              const SizedBox(height: 16),
              
              // 공사 설명
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '상세 설명 *',
                  hintText: '공사 내용을 자세히 설명해주세요',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '설명을 입력하세요' : null,
              ),
              const SizedBox(height: 16),
              
              // 예산
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '예산 (선택)',
                  hintText: '예상 공사 비용',
                  border: OutlineInputBorder(),
                  suffixText: '원',
                ),
              ),
              const SizedBox(height: 16),
              
              // 위치
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: '위치 (선택)',
                  hintText: '공사 진행할 장소',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // 카테고리 선택
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: '공사 카테고리',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) => 
                  DropdownMenuItem(value: category, child: Text(category))
                ).toList(),
                onChanged: (value) {
                  setState(() => _selectedCategory = value!);
                },
              ),
              const SizedBox(height: 16),
              
              // 긴급도 선택
              DropdownButtonFormField<String>(
                value: _selectedUrgency,
                decoration: const InputDecoration(
                  labelText: '긴급도',
                  border: OutlineInputBorder(),
                ),
                items: _urgencyLabels.entries.map((entry) => 
                  DropdownMenuItem(value: entry.key, child: Text(entry.value))
                ).toList(),
                onChanged: (value) {
                  setState(() => _selectedUrgency = value!);
                },
              ),
              const SizedBox(height: 24),
              
              // 안내 메시지
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.primaryContainer),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '공사 소개 시스템',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 등록된 공사를 다른 사업자에게 소개하여 수수료를 받을 수 있습니다\n'
                      '• 기본 수수료율: 5%\n'
                      '• 공사가 완료되면 자동으로 수수료가 계산됩니다',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // 등록 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _submitting ? null : _submitJob,
                  child: _submitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          '공사 등록',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


