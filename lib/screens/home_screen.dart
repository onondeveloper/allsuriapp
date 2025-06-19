import 'package:flutter/material.dart';
import '../models/role.dart';
import '../widgets/admin_dashboard.dart';
import '../widgets/business_dashboard.dart';
import '../widgets/customer_dashboard.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  final UserRole userRole;

  const HomeScreen({
    Key? key,
    required this.userRole,
  }) : super(key: key);

  String get _getTitle {
    switch (userRole) {
      case UserRole.admin:
        return '관리자 대시보드';
      case UserRole.business:
        return '사업자 대시보드';
      case UserRole.customer:
        return '견적 요청 대시보드';
    }
  }

  Widget _buildDashboard() {
    switch (userRole) {
      case UserRole.admin:
        return const AdminDashboard();
      case UserRole.business:
        // 테스트용 dummy authService, technicianId
        final dummyAuthService = AuthService();
        final dummyTechnicianId = 'tech_${DateTime.now().millisecondsSinceEpoch}';
        return BusinessDashboard(
          authService: dummyAuthService,
          technicianId: dummyTechnicianId,
        );
      case UserRole.customer:
        return const CustomerDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // TODO: Implement profile view
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: _buildDashboard(),
    );
  }
} 