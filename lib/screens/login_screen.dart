import 'package:flutter/material.dart';
import '../../models/role.dart';
import 'home/home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('로그인'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(userRole: UserRole.customer),
                  ),
                );
              },
              child: const Text('고객으로 로그인'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(userRole: UserRole.business),
                  ),
                );
              },
              child: const Text('사업자로 로그인'),
            ),
          ],
        ),
      ),
    );
  }
} 