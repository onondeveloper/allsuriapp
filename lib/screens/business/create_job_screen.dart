import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../services/marketplace_service.dart';
import '../../services/media_service.dart';
import '../../services/notification_service.dart';
import '../../services/kakao_share_service.dart';
import 'transfer_job_screen.dart';
import 'order_marketplace_screen.dart';
import '../../widgets/interactive_card.dart';
import 'package:flutter/services.dart';
import '../../utils/navigation_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final TextEditingController _feeRateController = TextEditingController(text: '5');
  final TextEditingController _feeAmountController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  String _selectedCategory = '일반';
  String _selectedUrgency = 'normal';
  bool _submitting = false;
  final MarketplaceService _marketplaceService = MarketplaceService();
  
  // 이미지 관련 상태
  final MediaService _mediaService = MediaService();
  final List<File> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  bool _isUploadingImages = false;

  final List<String> _categories = [
    '일반', '전기', '수도', '난방', '에어컨', '인테리어', '청소', '기타'
  ];

  final Map<String, String> _urgencyLabels = const {};

  @override
  void initState() {
    super.initState();
    
    // 🔒 사업자 승인 상태 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBusinessApproval();
    });
  }
  
  /// 🔒 사업자 승인 상태 확인
  void _checkBusinessApproval() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (user.role != 'business') {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사업자 계정만 접근 가능합니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (user.businessStatus != 'approved') {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사업자 승인이 필요합니다. 관리자 승인 후 이용 가능합니다.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    _feeRateController.dispose();
    _feeAmountController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _recalcFee() {
    final rawBudget = _budgetController.text.replaceAll(',', '');
    final budget = double.tryParse(rawBudget) ?? 0;
    final rate = double.tryParse(_feeRateController.text) ?? 0;
    final fee = (budget * rate / 100).round();
    final formatted = _ThousandsFormatter()._format(fee);
    _feeAmountController.text = formatted;
  }

  Future<void> _pickImages() async {
    try {
      final images = await _mediaService.pickMultipleImages();
      if (images != null && images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 실패: $e')),
        );
      }
    }
  }

  Future<void> _pickSingleImage() async {
    try {
      final image = await _mediaService.pickImageFromGallery();
      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
        // 자동 업로드
        await _uploadImages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 실패: $e')),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final image = await _mediaService.pickImageFromCamera();
      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
        // 자동 업로드
        await _uploadImages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카메라 촬영 실패: $e')),
        );
      }
    }
  }

  void _showImageSourceOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('사진 추가'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImageFromCamera();
            },
            child: const Text('카메라로 찍기'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickSingleImage();
            },
            child: const Text('앨범에서 선택'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ),
    );
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) return;

    setState(() => _isUploadingImages = true);

    try {
      print('🔍 [_uploadImages] ${_selectedImages.length}개 이미지 업로드 시작');
      final List<String> urls = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        print('   이미지 $i: ${image.path}');
        final url = await _mediaService.uploadEstimateImage(file: image);
        print('   반환된 URL: $url');
        if (url != null) {
          urls.add(url);
        }
      }

      print('✅ [_uploadImages] 총 ${urls.length}개 URL 수집됨');
      print('   URLs: $urls');
      
      setState(() {
        _uploadedImageUrls.addAll(urls);
        _selectedImages.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${urls.length}개 이미지가 업로드되었습니다')),
        );
      }
    } catch (e) {
      print('❌ [_uploadImages] 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 업로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImages = false);
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeUploadedImage(int index) {
    setState(() {
      _uploadedImageUrls.removeAt(index);
    });
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _submitting = true);
    
    try {
      final auth = context.read<AuthService>();
      final jobService = context.read<JobService>();
      final ownerId = auth.currentUser?.id;
      
      print('🔍 [_submitJob] 공사 생성 시작');
      print('   사용자 ID: $ownerId');
      print('   업로드된 이미지 URL 개수: ${_uploadedImageUrls.length}');
      print('   업로드된 이미지 URLs: $_uploadedImageUrls');
      
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

      print('   제목: ${_titleController.text.trim()}');
      print('   예산: $budget');
      print('   카테고리: $_selectedCategory');
      print('   → jobs 테이블에 저장 중...');

      final createdJobId = await jobService.createJob(
        ownerBusinessId: ownerId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        budgetAmount: budget,
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        category: _selectedCategory,
        urgency: 'normal',
        commissionRate: double.tryParse(_feeRateController.text) ?? 5.0,
        mediaUrls: _uploadedImageUrls.isEmpty ? null : _uploadedImageUrls,
      );

      print('   ✅ 공사 생성 완료: $createdJobId');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공사가 성공적으로 등록되었습니다!')),
      );

      // 다음 단계 선택: 오더로 올리기 또는 이관하기
      if (!mounted) return;
      await _showPostCreateOptions(createdJobId,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          budget: budget,
          region: _locationController.text.trim(),
          category: _selectedCategory);
      
      // ✅ 강제 홈 이동 코드 제거 (바텀시트 내부 로직에서 처리됨)
      
    } catch (e) {
      print('❌ [_submitJob] 실패: $e');
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
              // 사진 첨부 섹션
              InteractiveCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.photo_camera, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '사진 첨부',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        if (_selectedImages.isNotEmpty || _uploadedImageUrls.isNotEmpty)
                          Text(
                            '${_selectedImages.length + _uploadedImageUrls.length}개',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showImageSourceOptions,
                            icon: const Icon(Icons.add_photo_alternate, size: 18),
                            label: const Text('사진 선택'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (_selectedImages.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isUploadingImages ? null : _uploadImages,
                              icon: _isUploadingImages
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.cloud_upload, size: 18),
                              label: Text(_isUploadingImages ? '업로드 중...' : '업로드'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // 선택된 이미지 미리보기
                    if (_selectedImages.isNotEmpty || _uploadedImageUrls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length + _uploadedImageUrls.length,
                          itemBuilder: (context, index) {
                            final isUploaded = index >= _selectedImages.length;
                            final imageIndex = isUploaded ? index - _selectedImages.length : index;
                            
                            return Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    if (isUploaded)
                                      Image.network(
                                        _uploadedImageUrls[imageIndex],
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.broken_image, color: Colors.grey),
                                          );
                                        },
                                      )
                                    else
                                      Image.file(
                                        _selectedImages[index],
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          if (isUploaded) {
                                            _removeUploadedImage(imageIndex);
                                          } else {
                                            _removeImage(index);
                                          }
                                        },
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 기본 정보 (제목/설명)
              InteractiveCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 금액/수수료
              InteractiveCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '공사 금액 *',
                        hintText: '예상 공사 비용',
                        border: OutlineInputBorder(),
                        suffixText: '원',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                        _ThousandsFormatter(),
                      ],
                      validator: (v) => (v == null || v.trim().isEmpty) ? '공사 금액을 입력하세요' : null,
                      onChanged: (_) => _recalcFee(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _feeRateController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '수수료율(%) *',
                              border: OutlineInputBorder(),
                              suffixText: '%',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? '수수료율을 입력하세요' : null,
                            onChanged: (_) => _recalcFee(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _feeAmountController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: '수수료(원)',
                              border: OutlineInputBorder(),
                              suffixText: '원',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 위치/카테고리
              InteractiveCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: '위치 *',
                        hintText: '공사 진행할 장소',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '위치를 입력하세요' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: '공사 카테고리 *',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) => 
                        DropdownMenuItem(value: category, child: Text(category))
                      ).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCategory = value!);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 긴급도 제거
              const SizedBox(height: 24),
              
              // 안내 메시지 제거
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

  Future<void> _showPostCreateOptions(
    String jobId, {
    required String title,
    required String description,
    double? budget,
    String? region,
    required String category,
  }) async {
    if (!mounted) return;
    // 부모 컨텍스트를 저장하여, 바텀시트가 닫힌 뒤에도 안전하게 네비게이션/스낵바를 사용할 수 있도록 함
    final parentContext = context;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '공사 등록 완료!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '다음 작업을 선택하세요',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // 오더 버튼 (메인 - 크고 눈에 띄게)
                Container(
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A90E2).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      try {
                        print('오더 등록 시작: jobId=$jobId, title=$title');
                        
                        // 현재 사용자 ID 가져오기
                        final auth = context.read<AuthService>();
                        final currentUserId = auth.currentUser?.id;
                        print('   현재 사용자 ID: $currentUserId');
                        
                        final result = await _marketplaceService.createListing(
                          jobId: jobId,
                          title: title,
                          description: description,
                          region: (region ?? '').isEmpty ? null : region,
                          category: category,
                          budgetAmount: budget,
                          postedBy: currentUserId, // 사용자 ID 명시적 전달
                        );
                        
                        print('오더 등록 결과: $result');
                          
                          if (!mounted) return;
                          
                          if (result != null) {
                            print('OrderMarketplaceScreen으로 네비게이션 시작');
                            
                            // 다른 사업자들에게 알림 전송
                            try {
                              final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                              final notificationService = NotificationService();
                              
                              // 모든 사업자(자신 제외) 조회
                              final businessUsers = await Supabase.instance.client
                                .from('users')
                                .select('id, businessname')
                                .eq('usertype', 'business')
                                .neq('id', currentUserId ?? '');
                              
                              print('🔔 ${businessUsers.length}명의 사업자에게 알림 전송 중...');
                              
                              // 각 사업자에게 알림 전송
                              for (final business in businessUsers) {
                                try {
                                  await notificationService.sendNotification(
                                    userId: business['id'],
                                    title: '새로운 오더 등록',
                                    body: '$title - 새로운 공사 오더가 등록되었습니다!',
                                    type: 'new_order',
                                    orderId: result['id']?.toString(),
                                    jobTitle: title,
                                    region: region,
                                  );
                                } catch (e) {
                                  print('⚠️ 알림 전송 실패 (${business['businessname']}): $e');
                                }
                              }
                              
                              print('✅ 알림 전송 완료');
                            } catch (e) {
                              print('⚠️ 알림 전송 중 오류 (무시됨): $e');
                            }
                            
                            // 1. 카카오톡 공유 트리거 (비동기로 실행하여 화면 전환을 방해하지 않음)
                            // ※ 카카오톡 앱이 뜨는 동안 앱은 리스트 화면으로 넘어갑니다.
                            print('🔍 [CreateJobScreen] 카카오톡 공유 실행 (배경)');
                            KakaoShareService().shareOrder(
                              orderId: result['id']?.toString() ?? '',
                              title: title,
                              region: region ?? '',
                              category: category,
                              budgetAmount: budget,
                              commissionRate: double.tryParse(_feeRateController.text) ?? 5.0,
                              imageUrl: _uploadedImageUrls.isNotEmpty ? _uploadedImageUrls.first : null,
                              description: description,
                            );
                            
                            // 2. 오더 리스트 화면으로 즉시 이동
                            if (!mounted) return;
                            print('🔍 [CreateJobScreen] 오더 리스트 화면으로 즉시 이동');
                            
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderMarketplaceScreen(
                                  showSuccessMessage: true,
                                  createdByUserId: currentUserId,
                                ),
                              ),
                              (route) => route.isFirst,
                            );
                          } else {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('Call 등록에 실패했습니다. 다시 시도해주세요.')),
                            );
                          }
                      } catch (e) {
                        print('오더 등록 에러: $e');
                        if (!mounted) return;
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(content: Text('Call 등록 실패: $e')),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.campaign, size: 28),
                    label: const Text(
                      '오더로 올리기 (추천)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 이관하기 버튼 (서브 - 작고 부드럽게)
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      parentContext,
                      MaterialPageRoute(
                        builder: (_) => TransferJobScreen(jobId: jobId),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  icon: Icon(Icons.swap_horiz, size: 20, color: Colors.grey[700]),
                  label: Text(
                    '다른 사업자에게 이관하기',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final raw = newValue.text.replaceAll(',', '');
    final n = int.tryParse(raw);
    if (n == null) return oldValue;
    final formatted = _format(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(int number) {
    final s = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      buffer.write(s[s.length - 1 - i]);
      if ((i + 1) % 3 == 0 && i + 1 != s.length) buffer.write(',');
    }
    return buffer.toString().split('').reversed.join();
  }
}


