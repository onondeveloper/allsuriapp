import 'package:flutter/material.dart';

class BusinessPendingScreen extends StatelessWidget {
  const BusinessPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사업자 승인 대기')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.hourglass_bottom, size: 64, color: Colors.orange),
              SizedBox(height: 16),
              Text(
                '사업자 승인 검토 중입니다.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                '관리자가 검토 후 승인하면 알림으로 알려드릴게요.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


