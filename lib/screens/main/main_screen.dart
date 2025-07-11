import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_app_bar.dart';
import '../auth/login_screen.dart';
import '../role_selection_screen.dart';
import '../home/home_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (!authService.isAuthenticated) {
          return const LoginScreen();
        }

        final user = authService.currentUser;
        if (user == null) {
          return const RoleSelectionScreen();
        }

        return Scaffold(
          appBar: const CommonAppBar(),
          body: const HomeScreen(),
        );
      },
    );
  }
} 