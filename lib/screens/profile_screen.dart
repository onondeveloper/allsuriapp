import 'package:flutter/material.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
            ),
            const SizedBox(height: 20),
            const ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('사용자 이름'),
              subtitle: Text('홍길동'),
            ),
            const ListTile(
              leading: Icon(Icons.email_outlined),
              title: Text('이메일'),
              subtitle: Text('example@email.com'),
            ),
            const ListTile(
              leading: Icon(Icons.phone_outlined),
              title: Text('연락처'),
              subtitle: Text('010-1234-5678'),
            ),
          ],
        ),
      ),
    );
  }
} 