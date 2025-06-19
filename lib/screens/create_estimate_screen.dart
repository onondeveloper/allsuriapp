import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/order.dart';
import '../models/estimate.dart';
import '../services/estimate_service.dart';
import '../services/auth_service.dart';

class CreateEstimateScreen extends StatefulWidget {
  final Order order;
  final AuthService authService;
  final String technicianId;

  const CreateEstimateScreen({
    Key? key,
    required this.order,
    required this.authService,
    required this.technicianId,
  }) : super(key: key);

  @override
  State<CreateEstimateScreen> createState() => _CreateEstimateScreenState();
}

class _CreateEstimateScreenState extends State<CreateEstimateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _daysController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _priceController.dispose();
    _descriptionController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _submitEstimate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final estimateService = EstimateService(widget.authService);
      final estimate = Estimate(
        id: const Uuid().v4(),
        orderId: widget.order.id,
        technicianId: widget.technicianId,
        price: double.parse(_priceController.text.replaceAll(',', '')),
        description: _descriptionController.text,
        estimatedDays: int.parse(_daysController.text),
        createdAt: DateTime.now(),
        status: 'PENDING',
      );

      await estimateService.createEstimate(estimate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('견적이 성공적으로 제출되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('견적 제안 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('견적 제안하기'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderSummary(),
                const SizedBox(height: 24),
                _buildEstimateForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '견적 요청 정보',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(widget.order.title),
            const SizedBox(height: 8),
            Text('주소: ${widget.order.address}'),
            const SizedBox(height: 8),
            Text('방문 희망일: ${widget.order.visitDate.toString().split(' ')[0]}'),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimateForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '견적 정보 입력',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _priceController,
          decoration: const InputDecoration(
            labelText: '견적 금액',
            hintText: '예: 150000',
            prefixText: '₩ ',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _ThousandsSeparatorInputFormatter(),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '견적 금액을 입력해주세요';
            }
            final price = double.tryParse(value.replaceAll(',', ''));
            if (price == null || price <= 0) {
              return '올바른 금액을 입력해주세요';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _daysController,
          decoration: const InputDecoration(
            labelText: '예상 작업 기간 (일)',
            hintText: '예: 3',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '예상 작업 기간을 입력해주세요';
            }
            final days = int.tryParse(value);
            if (days == null || days <= 0) {
              return '올바른 작업 기간을 입력해주세요';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: '견적 설명',
            hintText: '작업 내용과 견적 산출 근거를 상세히 설명해주세요',
          ),
          maxLines: 5,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '견적 설명을 입력해주세요';
            }
            if (value.length < 10) {
              return '최소 10자 이상 입력해주세요';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitEstimate,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('견적 제안하기'),
          ),
        ),
      ],
    );
  }
}

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final value = int.tryParse(newValue.text.replaceAll(',', ''));
    if (value == null) {
      return oldValue;
    }

    final formatted = value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
} 