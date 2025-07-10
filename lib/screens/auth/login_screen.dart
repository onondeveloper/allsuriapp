import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart' as app_user;
import '../../models/role.dart';
import '../../utils/responsive_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 앱 로고
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.08),
                        spreadRadius: 2,
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      width: 100,
                      height: 100,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '올수리',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222B45),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '전문가와 연결하는 수리 서비스',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF7B8794),
                  ),
                ),
                const SizedBox(height: 48),
                
                const SizedBox(height: 40),
                
                // 역할 선택 버튼들
                _buildRoleButton(UserRole.customer, const Color(0xFF4F8CFF), '고객으로 시작하기'),
                const SizedBox(height: 16),
                _buildRoleButton(UserRole.business, const Color(0xFF00C6AE), '사업자로 시작하기'),
                const SizedBox(height: 16),
                _buildRoleButton(UserRole.admin, const Color(0xFFFF6B6B), '관리자로 시작하기'),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.signInWithGoogle();
      
      if (success && mounted) {
        // AuthService에서 자동으로 사용자 정보를 설정하므로
        // 기본적으로 고객 페이지로 이동
        context.go('/customer');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google 로그인이 취소되었습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 중 오류가 발생했습니다: $e'),
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

  Future<void> _selectRole(UserRole role) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (role == UserRole.customer) {
        // 고객의 경우 로그인 없이 바로 고객 홈 화면으로 이동
        if (mounted) {
          context.go('/customer');
        }
      } else {
        // 사업자와 관리자의 경우 구글 로그인 진행
        final authService = Provider.of<AuthService>(context, listen: false);
        final success = await authService.signInWithGoogle();
        
        if (success && mounted) {
          // 로그인 성공 시 선택된 역할로 사용자 생성
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final testUser = app_user.User(
            id: 'test_${role.name}_${DateTime.now().millisecondsSinceEpoch}',
            email: 'test_${role.name}@example.com',
            name: '테스트 ${_getRoleDisplayName(role)}',
            role: role,
            phoneNumber: '010-1234-5678',
          );
          
          await userProvider.setCurrentUser(testUser);
          
          // 역할에 따라 해당 페이지로 이동
          if (mounted) {
            switch (role) {
              case UserRole.admin:
                context.go('/admin');
                break;
              case UserRole.business:
                context.go('/business');
                break;
              case UserRole.customer:
                context.go('/customer');
                break;
            }
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google 로그인이 취소되었습니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 중 오류가 발생했습니다: $e'),
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

  Widget _buildRoleButton(UserRole role, Color color, String text) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _selectRole(role),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: color.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildGoogleLoginButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _signInWithGoogle,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Image.asset(
                    'assets/images/google_logo.png',
                    height: 36,
                    width: 36,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.login,
                          size: 28,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return '관리자';
      case UserRole.business:
        return '사업자';
      case UserRole.customer:
        return '고객';
    }
  }
}