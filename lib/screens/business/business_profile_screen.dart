import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_app_bar.dart';
import 'package:go_router/go_router.dart';
import '../../utils/navigation_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/star_rating.dart';
import '../../services/review_service.dart';
import '../../services/media_service.dart';
import 'package:app_settings/app_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({Key? key}) : super(key: key);

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessNumberController = TextEditingController();
  final _addressController = TextEditingController();
  // 결제/정산용 계정 설정 필드
  final _accountHolderController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _settlementEmailController = TextEditingController();
  
  List<String> _selectedServiceAreas = [];
  List<String> _selectedSpecialties = [];
  bool _isLoading = false;
  double _avgRating = 0;
  int _reviewCount = 0;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  void _loadCurrentUserData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    
    if (currentUser != null) {
      _nameController.text = currentUser.name;
      _phoneController.text = currentUser.phoneNumber ?? '';
      _businessNameController.text = currentUser.businessName ?? '';
      _businessNumberController.text = currentUser.businessNumber ?? '';
      _addressController.text = currentUser.address ?? '';
      _selectedServiceAreas = List.from(currentUser.serviceAreas);
      _selectedSpecialties = List.from(currentUser.specialties);
      _avatarUrl = currentUser.avatarUrl;
    }
    // 로컬 결제/정산 정보 로드
    Future.microtask(_loadBillingInfoFromLocal);
    // 리뷰 통계 로드
    Future.microtask(_loadRatingStats);
  }

  Future<void> _loadRatingStats() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final userId = auth.currentUser?.id ?? '';
      if (userId.isEmpty) return;
      final stats = await ReviewService().getBusinessStats(userId);
      if (mounted) setState(() {
        _avgRating = stats?.averageRating ?? 0;
        _reviewCount = stats?.totalReviews ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _loadBillingInfoFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _accountHolderController.text = prefs.getString('billing_account_holder') ?? '';
    _bankNameController.text = prefs.getString('billing_bank_name') ?? '';
    _accountNumberController.text = prefs.getString('billing_account_number') ?? '';
    _settlementEmailController.text = prefs.getString('billing_email') ?? '';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessNumberController.dispose();
    _addressController.dispose();
    _accountHolderController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _settlementEmailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 추가 필수/형식 검증
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final bizName = _businessNameController.text.trim();
    if (name.isEmpty || phone.isEmpty || bizName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름, 전화번호, 상호명은 필수입니다.')),
      );
      return;
    }
    final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneDigits.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화번호 형식을 확인해 주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.updateBusinessProfile(
        name: name,
        phoneNumber: phone,
        businessName: bizName,
        businessNumber: _businessNumberController.text.trim(),
        address: _addressController.text.trim(),
        serviceAreas: _selectedServiceAreas,
        specialties: _selectedSpecialties,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필이 성공적으로 저장되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        String friendly = '프로필 저장 중 오류가 발생했습니다.';
        if (msg.contains('invalid input syntax for type uuid')) {
          friendly = '임시 계정(ID) 형식 문제로 서버 저장을 건너뛰었습니다. 프로필은 기기에 저장되었습니다.';
        } else if (msg.contains('required') || msg.contains('null value')) {
          friendly = '필수 입력 항목을 확인해 주세요.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendly), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showServiceAreaDialog() {
    String searchText = '';
    List<String> filteredCities = List.from(KoreanCities.cities);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filter cities based on search text
          filteredCities = KoreanCities.cities
              .where((city) => city.toLowerCase().contains(searchText.toLowerCase()))
              .toList();

          return AlertDialog(
            title: const Text('활동 지역 선택'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  Text('최대 5개까지 선택 가능합니다. (현재 ${_selectedServiceAreas.length}개)'),
                  const SizedBox(height: 16),
                  TextField( // Search input field
                    decoration: InputDecoration(
                      hintText: '지역 검색',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        searchText = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredCities.length,
                      itemBuilder: (context, index) {
                        final city = filteredCities[index];
                        final isSelected = _selectedServiceAreas.contains(city);

                        return CheckboxListTile(
                          title: Text(city),
                          value: isSelected,
                          onChanged: (bool? value) {
                            setDialogState(() { // Use setDialogState to update the dialog's state
                              if (value == true) {
                                if (_selectedServiceAreas.length < 5) {
                                  _selectedServiceAreas.add(city);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('최대 5개까지만 선택할 수 있습니다.'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              } else {
                                _selectedServiceAreas.remove(city);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSpecialtyDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('전문 분야 선택'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: EquipmentCategories.categories.length,
              itemBuilder: (context, index) {
                final category = EquipmentCategories.categories[index];
                final isSelected = _selectedSpecialties.contains(category);
                
                return CheckboxListTile(
                  title: Text(category),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedSpecialties.add(category);
                      } else {
                        _selectedSpecialties.remove(category);
                      }
                    });
                    setDialogState(() {}); // Dialog 내부 UI 업데이트
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        NavigationUtils.navigateToRoleHome(context);
        return false;
      },
      child: Scaffold(
      appBar: CommonAppBar(
        title: '사업자 프로필',
        showBackButton: true,
        showHomeButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 헤더: 상호명 표시 (프레임 내 Ellipsis)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _onChangeAvatar,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty) ? NetworkImage(_avatarUrl!) : null,
                        child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                            ? const Icon(Icons.storefront, size: 20)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _businessNameController.text.isNotEmpty
                            ? _businessNameController.text
                            : '상호명을 입력하세요',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_avgRating > 0 || _reviewCount > 0)
                Row(
                  children: [
                    StarRating(rating: _avgRating, size: 18),
                    const SizedBox(width: 6),
                    Text('$_avgRating ($_reviewCount)', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              const SizedBox(height: 16),
              // 기본 정보 섹션
              _buildSection(
                '기본 정보',
                [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '이름 *',
                      hintText: '사업자 이름을 입력하세요',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '이름을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: '전화번호 *',
                      hintText: '010-1234-5678',
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _PhoneNumberFormatter(),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '전화번호를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),

              // 계정 설정 (결제)
              _buildSection(
                '계정 설정 (결제)',
                [
                  TextFormField(
                    controller: _accountHolderController,
                    decoration: const InputDecoration(
                      labelText: '예금주',
                      hintText: '예: 홍길동',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bankNameController,
                    decoration: const InputDecoration(
                      labelText: '은행명',
                      hintText: '예: 국민은행',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _accountNumberController,
                    decoration: const InputDecoration(
                      labelText: '계좌번호',
                      hintText: '하이픈 없이 입력',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _settlementEmailController,
                    decoration: const InputDecoration(
                      labelText: '정산 이메일',
                      hintText: '정산 관련 안내를 받을 이메일',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 알림 설정 섹션
              _buildSection(
                '알림 설정',
                [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_active),
                    title: const Text('기기 알림 설정 열기'),
                    subtitle: const Text('OS의 앱 알림 설정으로 이동합니다.'),
                    onTap: () {
                      AppSettings.openAppSettings();
                    },
                  ),
                ],
              ),
              
              // 사업자 정보 섹션
              _buildSection(
                '사업자 정보',
                [
                  TextFormField(
                    controller: _businessNameController,
                    decoration: const InputDecoration(
                      labelText: '상호명 *',
                      hintText: '사업자 상호명을 입력하세요',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '상호명을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _businessNumberController,
                    decoration: const InputDecoration(
                      labelText: '사업자 번호',
                      hintText: '123-45-67890',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: '주소',
                      hintText: '주소를 검색하세요',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _openAddressSearch,
                      ),
                    ),
                    readOnly: true,
                    onTap: _openAddressSearch,
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // 활동 지역 섹션
              _buildSection(
                '활동 지역',
                [
                  Material(
                    elevation: 0,
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    child: InkWell(
                      onTap: _showServiceAreaDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '활동 지역 선택',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedServiceAreas.isEmpty
                                  ? '활동 지역을 선택해주세요 (최대 5개)'
                                  : '선택된 지역: ${_selectedServiceAreas.join(', ')}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: _selectedServiceAreas.isEmpty
                                        ? Theme.of(context).colorScheme.onSurfaceVariant
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontWeight: _selectedServiceAreas.isEmpty 
                                        ? FontWeight.w400 
                                        : FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // 전문 분야 섹션
              _buildSection(
                '전문 분야',
                [
                  Material(
                    elevation: 0,
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    child: InkWell(
                      onTap: _showSpecialtyDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.work_rounded,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '전문 분야 선택',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedSpecialties.isEmpty
                                  ? '전문 분야를 선택해주세요'
                                  : '선택된 분야: ${_selectedSpecialties.join(', ')}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: _selectedSpecialties.isEmpty
                                        ? Theme.of(context).colorScheme.onSurfaceVariant
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontWeight: _selectedSpecialties.isEmpty 
                                        ? FontWeight.w400 
                                        : FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // 저장 버튼
              FilledButton.icon(
                onPressed: _isLoading ? null : _saveProfile,
                icon: _isLoading 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 22),
                label: Text(
                  _isLoading ? '저장 중...' : '프로필 저장',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // 로그아웃 버튼
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await Provider.of<AuthService>(context, listen: false).signOut();
                    if (mounted) NavigationUtils.navigateToRoleHome(context);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('로그아웃 실패: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('로그아웃'),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Future<void> _onChangeAvatar() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final me = auth.currentUser;
      if (me == null) return;
      final media = MediaService();
      final file = await media.pickImageFromGallery();
      if (file == null) return;
      final url = await media.uploadProfileImage(userId: me.id, file: file);
      if (url == null) return;
      await Supabase.instance.client.from('users').update({'avatar_url': url}).eq('id', me.id);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
    } catch (_) {}
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF222B45),
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Future<void> _openAddressSearch() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final url = request.url;
          final allowed = url.startsWith('https://t1.daumcdn.net') ||
                          url.startsWith('https://postcode.map.daum.net') ||
                          url.startsWith('https://map.daum.net') ||
                          url.startsWith('https://kakao.com') ||
                          url.startsWith('https://www.kakao.com');
          return allowed ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
      ))
      ..addJavaScriptChannel('flutter', onMessageReceived: (msg) {
        try {
          final Map<String, dynamic> data = json.decode(msg.message) as Map<String, dynamic>;
          final addr = (data['roadAddress']?.toString().isNotEmpty ?? false)
              ? data['roadAddress'].toString()
              : (data['address']?.toString() ?? '');
          setState(() {
            _addressController.text = addr;
          });
        } catch (_) {}
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      });

    final html = '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Kakao Postcode</title>
  <script src="https://t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"></script>
  <style>
    html, body, #wrap { height: 100%; margin: 0; }
    #wrap { display: flex; }
    #container { flex: 1; }
  </style>
  <script>
    function sendAddressToFlutter(payload) {
      if (window.flutter && window.flutter.postMessage) {
        window.flutter.postMessage(payload);
      }
    }
    window.onload = function() {
      new daum.Postcode({
        oncomplete: function(data) {
          const payload = JSON.stringify({
            address: data.address || '',
            roadAddress: data.roadAddress || '',
            jibunAddress: data.jibunAddress || '',
            zonecode: data.zonecode || ''
          });
          sendAddressToFlutter(payload);
        },
        width: '100%',
        height: '100%'
      }).embed(document.getElementById('container'));
    };
  </script>
</head>
<body>
  <div id="wrap">
    <div id="container"></div>
  </div>
</body>
</html>
''';

    await controller.loadHtmlString(html, baseUrl: 'https://postcode.map.daum.net');

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '주소 검색',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: WebViewWidget(controller: controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 전화번호 자동 하이픈 포맷터
class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    if (text.isEmpty) {
      return newValue;
    }

    String formatted = '';
    
    if (text.length <= 3) {
      formatted = text;
    } else if (text.length <= 7) {
      formatted = '${text.substring(0, 3)}-${text.substring(3)}';
    } else if (text.length <= 11) {
      formatted = '${text.substring(0, 3)}-${text.substring(3, 7)}-${text.substring(7)}';
    } else {
      formatted = '${text.substring(0, 3)}-${text.substring(3, 7)}-${text.substring(7, 11)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
} 