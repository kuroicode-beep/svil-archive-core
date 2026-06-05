// SAC 앱 진입점 — Friendly Light 기본 테마

import 'package:flutter/material.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const SacApp());
}

class SacApp extends StatelessWidget {
  const SacApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAC — SVIL Archive Core',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      // TODO(Cursor): ThemeService 연동 후 themeMode 동적 변경
      themeMode: ThemeMode.light,
      home: const WelcomeScreen(),
    );
  }
}
