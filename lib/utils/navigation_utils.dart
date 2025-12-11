import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/home/home_screen.dart';
import '../widgets/professional_dashboard.dart';

class NavigationUtils {
  static void navigateToRoleHome(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    
    // 디버그 로깅 추가
    print('=== NavigationUtils Debug ===');
    print('isAuthenticated: ${auth.isAuthenticated}');
    print('currentUser: ${auth.currentUser}');
    print('userRole: ${auth.currentUser?.role}');
    print('============================');
    
    if (auth.isAuthenticated && auth.currentUser?.role == 'business') {
      print('Navigating to ProfessionalDashboard');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ProfessionalDashboard()),
        (route) => false,
      );
    } else {
      print('Navigating to HomeScreen (customer)');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }
}


