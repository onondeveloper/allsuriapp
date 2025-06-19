import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('알림 설정'),
            subtitle: const Text('푸시 알림을 받습니다'),
            value: true,
            onChanged: (bool value) {
              // 알림 설정 변경 로직
            },
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('앱 버전'),
            subtitle: Text('1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.description_outlined),
            title: Text('이용약관'),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('개인정보 처리방침'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () {
              // 로그아웃 로직
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
} 