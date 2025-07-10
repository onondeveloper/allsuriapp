import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common_app_bar.dart';
import 'package:go_router/go_router.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _selectedStatus = 'all';
  bool _isLoading = false;

  final List<String> _statusFilters = [
    'all',
    'pending',
    'approved',
    'rejected',
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadBusinessUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 목록을 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<User> _getFilteredUsers(List<User> users) {
    switch (_selectedStatus) {
      case 'pending':
        return users.where((user) => user.status == 'pending').toList();
      case 'approved':
        return users.where((user) => user.status == 'approved').toList();
      case 'rejected':
        return users.where((user) => user.status == 'rejected').toList();
      default:
        return users;
    }
  }

  Future<void> _approveUser(User user) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.updateUserStatus(user.id, 'approved');
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name}님의 계정이 승인되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('승인 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _rejectUser(User user) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.updateUserStatus(user.id, 'rejected');
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name}님의 계정이 거절되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('거절 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용자 삭제'),
        content: Text('${user.name}님의 계정을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.deleteUser(user.id);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name}님의 계정이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '사업자 관리',
        showBackButton: true,
        showHomeButton: true,
      ),
      body: Column(
        children: [
          // 필터 칩
          _buildFilterChips(),
          
          // 사용자 목록
          Expanded(
            child: Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final businessUsers = userProvider.businessUsers;
                final filteredUsers = _getFilteredUsers(businessUsers);

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedStatus == 'all' 
                              ? '등록된 사업자가 없습니다.'
                              : '선택한 상태의 사업자가 없습니다.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return _buildUserCard(user);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('전체', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('대기 중', 'pending'),
          const SizedBox(width: 8),
          _buildFilterChip('승인됨', 'approved'),
          const SizedBox(width: 8),
          _buildFilterChip('거절됨', 'rejected'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = value;
        });
      },
      selectedColor: const Color(0xFF4F8CFF).withOpacity(0.2),
      checkmarkColor: const Color(0xFF4F8CFF),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF4F8CFF) : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF4F8CFF).withOpacity(0.1),
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4F8CFF),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.phoneNumber ?? '전화번호 없음',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(user.status),
              ],
            ),
            const SizedBox(height: 12),
            if (user.serviceAreas.isNotEmpty || user.specialties.isNotEmpty) ...[
              Text(
                '사업자 정보',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              if (user.serviceAreas.isNotEmpty)
                Text(
                  '활동 지역: ${user.serviceAreas.join(', ')}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              if (user.serviceAreas.isNotEmpty && user.specialties.isNotEmpty)
                const SizedBox(height: 2),
              if (user.specialties.isNotEmpty)
                Text(
                  '전문 분야: ${user.specialties.join(', ')}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                if (user.status == 'pending') ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approveUser(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('승인'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectUser(user),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('거절'),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _deleteUser(user),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('삭제'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    String statusText;

    switch (status) {
      case 'pending':
        backgroundColor = Colors.orange;
        statusText = '대기';
        break;
      case 'approved':
        backgroundColor = Colors.green;
        statusText = '승인';
        break;
      case 'rejected':
        backgroundColor = Colors.red;
        statusText = '거절';
        break;
      default:
        backgroundColor = Colors.grey;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
} 