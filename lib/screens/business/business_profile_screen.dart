import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_app_bar.dart';
import 'package:go_router/go_router.dart';
import '../../utils/navigation_utils.dart';

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
  
  List<String> _selectedServiceAreas = [];
  List<String> _selectedSpecialties = [];
  bool _isLoading = false;

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
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.updateBusinessProfile(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        businessName: _businessNameController.text.trim(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('프로필 저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('활동 지역 선택'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Text('최대 5개까지 선택 가능합니다. (현재 ${_selectedServiceAreas.length}개)'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: KoreanCities.cities.length,
                  itemBuilder: (context, index) {
                    final city = KoreanCities.cities[index];
                    final isSelected = _selectedServiceAreas.contains(city);
                    
                    return CheckboxListTile(
                      title: Text(city),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
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
      ),
    );
  }

  void _showSpecialtyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                    decoration: const InputDecoration(
                      labelText: '주소',
                      hintText: '사업자 주소를 입력하세요',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // 활동 지역 섹션
              _buildSection(
                '활동 지역',
                [
                  InkWell(
                    onTap: _showServiceAreaDialog,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '활동 지역 선택',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.grey.shade600,
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedServiceAreas.isEmpty
                                ? '활동 지역을 선택해주세요 (최대 5개)'
                                : '선택된 지역: ${_selectedServiceAreas.join(', ')}',
                            style: TextStyle(
                              color: _selectedServiceAreas.isEmpty
                                  ? Colors.grey.shade600
                                  : Colors.black87,
                            ),
                          ),
                        ],
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
                  InkWell(
                    onTap: _showSpecialtyDialog,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '전문 분야 선택',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.grey.shade600,
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedSpecialties.isEmpty
                                ? '전문 분야를 선택해주세요'
                                : '선택된 분야: ${_selectedSpecialties.join(', ')}',
                            style: TextStyle(
                              color: _selectedSpecialties.isEmpty
                                  ? Colors.grey.shade600
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // 저장 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF4F8CFF),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        '프로필 저장',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ));
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
} 