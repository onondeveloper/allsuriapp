import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/business/business_profile_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('역할 선택'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '어떤 역할로 이용하시겠습니까?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            _RoleButton(label: '고객', role: 'customer'),
            const SizedBox(height: 20),
            _RoleButton(label: '사업자', role: 'business', pushOnboarding: true),
            const SizedBox(height: 20),
            _RoleButton(label: '관리자', role: 'admin'),
          ],
        ),
      ),
    );
  }
} 

class _RoleButton extends StatefulWidget {
  final String label;
  final String role;
  final bool pushOnboarding;
  const _RoleButton({required this.label, required this.role, this.pushOnboarding = false});

  @override
  State<_RoleButton> createState() => _RoleButtonState();
}

class _RoleButtonState extends State<_RoleButton> {
  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: ElevatedButton(
        onPressed: _loading
            ? null
            : () async {
                setState(() => _loading = true);
                try {
                  await context.read<AuthService>().updateRole(widget.role);
                  if (!mounted) return;
                  if (widget.pushOnboarding && widget.role == 'business') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
                    );
                  } else {
                    Navigator.pop(context);
                  }
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
        child: _loading ? const CircularProgressIndicator() : Text(widget.label),
      ),
    );
  }
}