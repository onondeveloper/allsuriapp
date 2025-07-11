import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/estimate.dart';
import '../models/order.dart';
import '../services/estimate_service.dart';
import '../services/auth_service.dart';

class CreateEstimateScreen extends StatefulWidget {
  final Order order;
  
  const CreateEstimateScreen({
    super.key,
    required this.order,
  });

  @override
  State<CreateEstimateScreen> createState() => _CreateEstimateScreenState();
}

class _CreateEstimateScreenState extends State<CreateEstimateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _estimatedDaysController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _estimatedDaysController.dispose();
    super.dispose();
  }

  Future<void> _submitEstimate() async {
    if (_amountController.text.trim().isEmpty) {
      _showError('견적 금액을 입력해주세요');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showError('견적 설명을 입력해주세요');
      return;
    }
    if (_estimatedDaysController.text.trim().isEmpty) {
      _showError('예상 소요일을 입력해주세요');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final estimateService = Provider.of<EstimateService>(context, listen: false);
      
      final user = authService.currentUser;
      if (user == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      final estimate = Estimate(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        orderId: widget.order.id,
        customerId: widget.order.customerId ?? '',
        customerName: widget.order.customerName,
        businessId: user.id,
        businessName: user.name,
        businessPhone: user.phoneNumber ?? '',
        equipmentType: widget.order.equipmentType,
        amount: double.parse(_amountController.text.trim()),
        description: _descriptionController.text.trim(),
        estimatedDays: int.parse(_estimatedDaysController.text.trim()),
        createdAt: DateTime.now(),
        visitDate: widget.order.visitDate,
        status: Estimate.STATUS_PENDING,
      );

      await estimateService.createEstimate(estimate);
      
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('견적 제출 완료'),
            content: const Text('견적이 성공적으로 제출되었습니다!'),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(context); // 다이얼로그 닫기
                  Navigator.pop(context); // 화면 닫기
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('견적 제출 중 오류가 발생했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('견적 작성'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 주문 정보 표시
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '견적 요청 정보',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.label,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '제목: ${widget.order.title}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '고객: ${widget.order.customerName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '카테고리: ${widget.order.equipmentType}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '주소: ${widget.order.address}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '방문일: ${widget.order.visitDate.toString().split(' ')[0]}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '설명: ${widget.order.description}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                const Text(
                  '견적 정보',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 16),
                
                CupertinoTextField(
                  controller: _amountController,
                  placeholder: '견적 금액 (원)',
                  keyboardType: TextInputType.number,
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.separator),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),
                
                CupertinoTextField(
                  controller: _descriptionController,
                  placeholder: '견적 설명을 입력해주세요',
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.separator),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                
                CupertinoTextField(
                  controller: _estimatedDaysController,
                  placeholder: '예상 소요일 (일)',
                  keyboardType: TextInputType.number,
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.separator),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _isSubmitting ? null : _submitEstimate,
                    child: _isSubmitting
                        ? const CupertinoActivityIndicator()
                        : const Text(
                            '견적 제출',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

    final text = newValue.text.replaceAll(',', '');
    final number = int.tryParse(text);
    
    if (number == null) {
      return oldValue;
    }

    final formatted = number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
} 