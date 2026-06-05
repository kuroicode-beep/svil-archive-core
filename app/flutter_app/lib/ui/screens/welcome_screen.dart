// Welcome / Workspace Setup placeholder

import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SAC — SVIL Archive Core',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO(Cursor): Workspace 선택 다이얼로그 연결
              },
              child: const Text('Workspace 열기 또는 생성'),
            ),
          ],
        ),
      ),
    );
  }
}
