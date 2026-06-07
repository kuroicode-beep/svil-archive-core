// main.dart — SAC 앱 진입점 (Desktop SQLite FFI 초기화 포함)

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'application/sac_container.dart';
import 'ui/screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final container = await SacContainer.create();
  runApp(SacApp(container: container));
}

class SacApp extends StatelessWidget {
  final SacContainer container;

  const SacApp({super.key, required this.container});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: container.themeController,
      builder: (context, _) {
        final controller = container.themeController;
        return MaterialApp(
          title: 'SAC — SVIL Archive Core',
          debugShowCheckedModeBanner: false,
          theme: controller.resolveTheme(),
          darkTheme: controller.resolveTheme(),
          themeMode: controller.resolveThemeMode(),
          home: WelcomeScreen(container: container),
        );
      },
    );
  }
}
