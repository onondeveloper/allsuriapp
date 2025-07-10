import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/role.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final bool showHomeButton;
  final List<Widget>? actions;

  const CommonAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.showHomeButton = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF222B45),
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      leading: showBackButton
          ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F8CFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_ios,
                  size: 20,
                  color: Color(0xFF4F8CFF),
                ),
              ),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  // 현재 경로를 확인하여 적절한 홈 화면으로 이동
                  final currentPath = GoRouterState.of(context).uri.path;
                  
                  if (currentPath.startsWith('/customer')) {
                    context.go('/customer');
                  } else if (currentPath.startsWith('/business')) {
                    context.go('/business');
                  } else if (currentPath.startsWith('/admin')) {
                    context.go('/admin');
                  } else {
                    // 기본적으로 사용자 역할에 따라 이동
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    final user = userProvider.currentUser;
                    if (user != null) {
                      switch (user.role) {
                        case UserRole.admin:
                          context.go('/admin');
                          break;
                        case UserRole.business:
                          context.go('/business');
                          break;
                        case UserRole.customer:
                        default:
                          context.go('/customer');
                          break;
                      }
                    } else {
                      context.go('/');
                    }
                  }
                }
              },
            )
          : null,
      actions: [
        if (showHomeButton)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4F8CFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.home,
                size: 20,
                color: Color(0xFF4F8CFF),
              ),
            ),
            onPressed: () {
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              final user = userProvider.currentUser;
              if (user != null) {
                switch (user.role) {
                  case UserRole.admin:
                    context.go('/admin');
                    break;
                  case UserRole.business:
                    context.go('/business');
                    break;
                  case UserRole.customer:
                  default:
                    context.go('/customer');
                    break;
                }
              } else {
                context.go('/');
              }
            },
          ),
        if (actions != null) ...actions!,
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
} 