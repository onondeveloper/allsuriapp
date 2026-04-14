import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/home/home_screen.dart';
class NavigationUtils {
  static void navigateToRoleHome(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);

    print('=== NavigationUtils Debug ===');
    print('isAuthenticated: ${auth.isAuthenticated}');
    print('currentUser: ${auth.currentUser}');
    print('userRole: ${auth.currentUser?.role}');
    print('============================');

    // HomeScreen이 로그인 시 사업자 온보딩/대시보드로 분기함
    print('Navigating to HomeScreen');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }
}


