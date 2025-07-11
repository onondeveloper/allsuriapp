import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/estimate.dart';
import '../../services/auth_service.dart';
import '../../services/estimate_service.dart';

class TransferEstimateScreen extends StatefulWidget {
  final Estimate estimate;
  
  const TransferEstimateScreen({
    super.key,
    required this.estimate,
  });

  @override
  State<TransferEstimateScreen> createState() => _TransferEstimateScreenState();
}

class _TransferEstimateScreenState extends State<TransferEstimateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _phoneNumberController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _transferEstimate() async {
    if (_businessNameController.text.trim().isEmpty) {
      _showError('상호명을 입력해주세요');
      return;
    }
    if (_phoneNumberController.text.trim().isEmpty) {
      _showError('전화번호를 입력해주세요');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final estimateService = Provider.of<EstimateService>(context, listen: false);
      
      // 견적 이관 처리
      await estimateService.transferEstimate(
        estimateId: widget.estimate.id,
        newBusinessName: _businessNameController.text.trim(),
        newPhoneNumber: _phoneNumberController.text.trim(),
        reason: _reasonController.text.trim(),
        transferredBy: Provider.of<AuthService>(context, listen: false).currentUser?.id ?? '',
      );

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('견적 이관 완료'),
            content: const Text('견적이 성공적으로 이관되었습니다.'),
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
        _showError('견적 이관 중 오류가 발생했습니다: $e');
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
        middle: Text('견적 이관'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 견적 정보 표시
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
                        '이관할 견적 정보',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.label,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '고객: ${widget.estimate.customerName}',
                        style: const TextStyle(color: CupertinoColors.secondaryLabel),
                      ),
                      Text(
                        '장비: ${widget.estimate.equipmentType}',
                        style: const TextStyle(color: CupertinoColors.secondaryLabel),
                      ),
                      Text(
                        '견적 금액: ${widget.estimate.amount.toStringAsFixed(0)}원',
                        style: const TextStyle(color: CupertinoColors.secondaryLabel),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                const Text(
                  '이관할 사업자 정보',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 16),
                
                CupertinoTextField(
                  controller: _businessNameController,
                  placeholder: '상호명을 입력해주세요',
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.separator),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),
                
                CupertinoTextField(
                  controller: _phoneNumberController,
                  placeholder: '전화번호를 입력해주세요 (예: 010-1234-5678)',
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.separator),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),
                
                CupertinoTextField(
                  controller: _reasonController,
                  placeholder: '이관 사유 (선택사항)',
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.separator),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _isSubmitting ? null : _transferEstimate,
                    child: _isSubmitting
                        ? const CupertinoActivityIndicator()
                        : const Text(
                            '견적 이관하기',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemYellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CupertinoColors.systemYellow.withOpacity(0.3),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_triangle,
                            color: CupertinoColors.systemYellow,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '주의사항',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: CupertinoColors.systemYellow,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• 견적 이관은 되돌릴 수 없습니다.\n'
                        '• 이관된 견적은 해당 사업자가 처리하게 됩니다.\n'
                        '• 고객에게 이관 사실이 자동으로 알림됩니다.',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemYellow,
                        ),
                      ),
                    ],
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
