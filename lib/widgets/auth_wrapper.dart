import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/role_selection_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
         if (authService.isAuthenticated) {
          final user = authService.currentUser;
          
          // 사용자 역할에 따라 적절한 화면으로 이동
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (user != null) {
              switch (user.role) {
                case 'admin':
                  context.go('/admin');
                  break;
                case 'business':
                  context.go('/business');
                  break;
                case 'customer':
                  context.go('/customer');
                  break;
                default:
                  // 역할이 설정되지 않은 경우 역할 선택 화면으로 이동
                  context.go('/role-selection');
                  break;
              }
            }
          });
          
          // 임시로 로딩 화면 표시
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
} 