import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/role.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  // TODO: Replace with actual data from backend
  final List<User> _users = [
    User(
      id: '1',
      email: 'admin@example.com',
      name: '관리자',
      role: UserRole.admin,
    ),
    User(
      id: '2',
      email: 'business@example.com',
      name: '사업자1',
      role: UserRole.business,
      businessName: '올수리 서비스',
      businessLicense: '123-45-67890',
    ),
    User(
      id: '3',
      email: 'customer@example.com',
      name: '고객1',
      role: UserRole.customer,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 관리'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: '사용자 검색',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                // TODO: Implement search functionality
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(user.name[0]),
                    ),
                    title: Text(user.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.email),
                        if (user.businessName != null)
                          Text('사업체명: ${user.businessName}'),
                      ],
                    ),
                    trailing: _buildRoleChip(user.role),
                    onTap: () => _showUserDetailsDialog(user),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement add user functionality
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRoleChip(UserRole role) {
    Color color;
    String label;

    switch (role) {
      case UserRole.admin:
        color = Colors.red;
        label = '관리자';
      case UserRole.business:
        color = Colors.blue;
        label = '사업자';
      case UserRole.customer:
        color = Colors.green;
        label = '고객';
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }

  void _showUserDetailsDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이메일: ${user.email}'),
            Text('역할: ${user.role.value}'),
            if (user.businessName != null)
              Text('사업체명: ${user.businessName}'),
            if (user.businessLicense != null)
              Text('사업자등록번호: ${user.businessLicense}'),
            if (user.phoneNumber != null)
              Text('연락처: ${user.phoneNumber}'),
            if (user.address != null) Text('주소: ${user.address}'),
            Text('가입일: ${user.createdAt.toString().split('.')[0]}'),
            Text('상태: ${user.isActive ? "활성" : "비활성"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Implement edit functionality
              Navigator.pop(context);
            },
            child: const Text('수정'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement status toggle functionality
              Navigator.pop(context);
            },
            child: Text(user.isActive ? '비활성화' : '활성화'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
} 