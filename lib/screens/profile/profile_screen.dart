import 'package:flutter/material.dart';

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
              // TODO: 설정 페이지로 이동
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              child: Icon(Icons.person, size: 50),
            ),
            const SizedBox(height: 16),
            const Text(
              '홍길동',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '일반 회원',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            const ListTile(
              leading: Icon(Icons.email),
              title: Text('이메일'),
              subtitle: Text('example@email.com'),
            ),
            const ListTile(
              leading: Icon(Icons.phone),
              title: Text('연락처'),
              subtitle: Text('010-1234-5678'),
            ),
            const ListTile(
              leading: Icon(Icons.location_on),
              title: Text('주소'),
              subtitle: Text('서울시 강남구'),
            ),
          ],
        ),
      ),
    );
  }
} 