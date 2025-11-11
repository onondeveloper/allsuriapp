import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/estimate.dart';
import '../../services/auth_service.dart';
import '../../services/estimate_service.dart';
import '../../services/chat_service.dart';

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
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingBusinesses = true;
  List<Map<String, dynamic>> _businesses = [];
  String? _selectedBusinessId;
  String? _selectedBusinessName;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    try {
      print('🔍 [TransferEstimate] 사업자 목록 로드 중...');
      final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.id;
      
      if (currentUserId == null || currentUserId.isEmpty) {
        print('❌ [TransferEstimate] 현재 사용자 ID 없음');
        throw Exception('로그인이 필요합니다');
      }
      
      // 플랫폼 내 모든 사업자 조회 (본인 제외)
      final response = await Supabase.instance.client
          .from('users')
          .select('id, businessname, name, phonenumber')
          .eq('role', 'business')
          .neq('id', currentUserId);
      
      print('✅ [TransferEstimate] ${response.length}명의 사업자 조회 완료');
      print('   첫 번째 사업자: ${response.isNotEmpty ? response[0] : "없음"}');
      
      if (response.isEmpty) {
        print('⚠️ [TransferEstimate] 이관 가능한 사업자가 없습니다');
      }
      
      setState(() {
        _businesses = List<Map<String, dynamic>>.from(response);
        _isLoadingBusinesses = false;
      });
    } catch (e) {
      print('❌ [TransferEstimate] 사업자 목록 조회 오류: $e');
      setState(() {
        _isLoadingBusinesses = false;
      });
      if (mounted) {
        _showError('사업자 목록을 불러오는데 실패했습니다: $e');
      }
    }
  }

  Future<void> _transferEstimate() async {
    if (_selectedBusinessId == null) {
      _showError('이관할 사업자를 선택해주세요');
      return;
    }

    setState(() => _isSubmitting = true);
    
    // 로딩 상태 메시지 표시
    if (mounted) {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (loadingContext) => CupertinoAlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 16),
              const SizedBox(height: 16),
              Text('$_selectedBusinessName님에게\n견적을 이관하고 있습니다...'),
            ],
          ),
        ),
      );
    }

    try {
      final estimateService = Provider.of<EstimateService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id ?? '';
      
      print('🔄 [TransferEstimate] 이관 시작: ${widget.estimate.id} -> $_selectedBusinessId');
      
      // 견적 이관 처리
      await estimateService.transferEstimate(
        estimateId: widget.estimate.id,
        newBusinessId: _selectedBusinessId!,
        newBusinessName: _selectedBusinessName ?? '',
        reason: _reasonController.text.trim(),
        transferredBy: currentUserId,
      );

      print('✅ [TransferEstimate] 이관 완료');

      // 채팅방 자동 생성 (이관하는 사업자 ↔ 이관받는 사업자)
      try {
        print('🔄 [TransferEstimate] 채팅방 생성 중...');
        final roomId = 'transfer_${widget.estimate.id}';
        await ChatService().createChatRoom(
          roomId,
          currentUserId,  // 이관하는 사업자
          _selectedBusinessId!,  // 이관받는 사업자
          estimateId: widget.estimate.id,
        );
        print('✅ [TransferEstimate] 채팅방 생성 완료: $roomId');
      } catch (chatErr) {
        print('⚠️ [TransferEstimate] 채팅방 생성 실패 (무시): $chatErr');
      }

      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('견적 이관 완료'),
            content: Text('$_selectedBusinessName님에게 견적이 성공적으로 이관되었습니다.\n채팅방이 자동으로 생성되었습니다.'),
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
      print('❌ [TransferEstimate] 이관 실패: $e');
      
      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
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
                  '이관할 사업자 선택',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 16),
                
                // 사업자 선택 드롭다운
                _isLoadingBusinesses
                    ? const Center(child: CupertinoActivityIndicator())
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: CupertinoColors.separator),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            showCupertinoModalPopup(
                              context: context,
                              builder: (BuildContext context) => Container(
                                height: 300,
                                color: CupertinoColors.systemBackground,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          CupertinoButton(
                                            child: const Text('취소'),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                          const Text(
                                            '사업자 선택',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          CupertinoButton(
                                            child: const Text('확인'),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: CupertinoPicker(
                                        itemExtent: 50,
                                        onSelectedItemChanged: (int index) {
                                          setState(() {
                                            _selectedBusinessId = _businesses[index]['id'];
                                            _selectedBusinessName = _businesses[index]['businessname'] ?? _businesses[index]['name'];
                                          });
                                        },
                                        children: _businesses.map((business) {
                                          final name = business['businessname'] ?? business['name'] ?? '알 수 없음';
                                          final phone = business['phonenumber'] ?? '';
                                          return Center(
                                            child: Text(
                                              '$name${phone.isNotEmpty ? ' ($phone)' : ''}',
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedBusinessName ?? '사업자를 선택해주세요',
                                style: TextStyle(
                                  color: _selectedBusinessName == null
                                      ? CupertinoColors.placeholderText
                                      : CupertinoColors.label,
                                ),
                              ),
                              const Icon(
                                CupertinoIcons.chevron_down,
                                size: 20,
                                color: CupertinoColors.systemGrey,
                              ),
                            ],
                          ),
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
