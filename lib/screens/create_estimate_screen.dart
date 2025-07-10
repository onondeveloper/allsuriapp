import 'package:allsuriapp/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../models/estimate.dart';
import '../widgets/common_app_bar.dart';

class CreateEstimateScreen extends StatefulWidget {
  final Order order;
  final String technicianId;

  const CreateEstimateScreen({
    Key? key,
    required this.order,
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
      final estimateService =
          Provider.of<EstimateService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      print('EstimateService and AuthService accessed successfully');
      
      // 디버깅: 전달된 technicianId와 현재 사용자 ID 확인
      print('=== 견적 생성 디버깅 ===');
      print('전달된 technicianId: ${widget.technicianId}');
      print('현재 사용자 ID: ${authService.currentUser?.id}');
      print('현재 사용자명: ${authService.currentUser?.name}');
      print('현재 사용자 역할: ${authService.currentUser?.role}');
      
      // 고유한 견적 ID 생성
      final estimateId = 'EST_${DateTime.now().millisecondsSinceEpoch}_${widget.technicianId.substring(0, 8)}';
      
      final estimate = Estimate(
        id: estimateId,
        orderId: widget.order.id,
        technicianId: widget.technicianId,
        technicianName: authService.currentUser?.name ?? '사업자',
        price: double.parse(_priceController.text.replaceAll(',', '')),
        description: _descriptionController.text,
        estimatedDays: int.parse(_daysController.text),
        createdAt: DateTime.now(),
        visitDate: widget.order.visitDate,
        status: Estimate.STATUS_PENDING,
      );

      print('생성할 견적 정보:');
      print('  - 견적 ID: ${estimate.id}');
      print('  - 주문 ID: ${estimate.orderId}');
      print('  - 기술자 ID: ${estimate.technicianId}');
      print('  - 기술자명: ${estimate.technicianName}');
      print('  - 견적 금액: ${estimate.price}');
      print('  - 견적 설명: ${estimate.description}');
      print('  - 예상 작업 기간: ${estimate.estimatedDays}일');
      print('  - 방문일: ${estimate.visitDate}');
      print('  - 상태: ${estimate.status}');

      await estimateService.createEstimate(estimate);
      if (mounted) {
        // 견적 제출 성공 후 다이얼로그 표시
        final result = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('견적 제출 완료'),
            content: const Text('견적이 성공적으로 제출되었습니다!\n\n다른 사업자에게 이관하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('close'),
                child: const Text('닫기'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop('transfer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F8CFF),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('이관 하기'),
              ),
            ],
          ),
        );

        if (result == 'transfer') {
          // 이관 화면으로 이동
          Navigator.of(context).pop(true);
          Navigator.of(context).pushNamed('/business/transfer-estimate', arguments: estimate);
        } else {
          Navigator.of(context).pop(true);
        }
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
    return WillPopScope(
      onWillPop: () async {
        // 뒤로 가기 버튼 처리
        if (_isSubmitting) {
          // 제출 중에는 뒤로 가기 방지
          return false;
        }
        
        // 폼에 데이터가 있으면 확인 다이얼로그 표시
        if (_priceController.text.isNotEmpty || 
            _descriptionController.text.isNotEmpty ||
            _daysController.text.isNotEmpty) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('견적 제안 취소'),
              content: const Text('입력한 내용이 있습니다. 정말로 나가시겠습니까?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('나가기'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        
        return true;
      },
      child: Scaffold(
        appBar: CommonAppBar(
          title: '견적 제안하기',
          showBackButton: true,
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