import 'package:flutter/material.dart';
import '../models/role.dart';
import '../screens/home_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  void _navigateToHome(BuildContext context, UserRole role) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(userRole: role),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, UserRole role, String title, String description, IconData icon) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: () => _navigateToHome(context, role),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).primaryColor),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('역할 선택'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '시작하기 전에 역할을 선택해주세요',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildRoleCard(
                context,
                UserRole.admin,
                '관리자',
                '사용자와 견적을 관리하고 시스템을 운영합니다',
                Icons.admin_panel_settings,
              ),
              _buildRoleCard(
                context,
                UserRole.business,
                '사업자',
                '견적을 생성하고 고객의 요청에 응답합니다',
                Icons.business,
              ),
              _buildRoleCard(
                context,
                UserRole.customer,
                '일반 사용자',
                '견적을 요청하고 사업자의 견적을 검토합니다',
                Icons.person,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 