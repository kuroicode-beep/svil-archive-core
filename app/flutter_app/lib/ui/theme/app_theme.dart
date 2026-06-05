// 테마 토큰 구조 — Dark(기본), Light, HighContrast placeholder
// 실제 색상값은 Cursor Sprint 2에서 디자인 소스 기준으로 확정

import 'package:flutter/material.dart';

class SacColors {
  // Dark theme tokens (기본값)
  static const backgroundDark = Color(0xFF1A1A1A);
  static const surfaceDark = Color(0xFF242424);
  static const textPrimaryDark = Color(0xFFEEEEEE);
  static const textSecondaryDark = Color(0xFF9E9E9E);
  static const accentDark = Color(0xFF64B5F6);

  // Light theme tokens
  static const backgroundLight = Color(0xFFF5F5F5);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textPrimaryLight = Color(0xFF1A1A1A);
  static const textSecondaryLight = Color(0xFF616161);
  static const accentLight = Color(0xFF1565C0);

  // High contrast tokens (저시력 최적화)
  static const backgroundHC = Color(0xFF000000);
  static const surfaceHC = Color(0xFF0D0D0D);
  static const textPrimaryHC = Color(0xFFFFFFFF);
  static const textAccentHC = Color(0xFFFFFF00);   // 노랑
  static const textCyanHC = Color(0xFF00FFFF);     // 시안
  static const accentHC = Color(0xFFFFFF00);
}

ThemeData buildLightTheme() => ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: SacColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        surface: SacColors.surfaceLight,
        primary: SacColors.accentLight,
      ),
    );

ThemeData buildDarkTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SacColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        surface: SacColors.surfaceDark,
        primary: SacColors.accentDark,
      ),
    );

// High contrast는 dark 기반으로 강화
ThemeData buildHighContrastTheme() => buildDarkTheme().copyWith(
      scaffoldBackgroundColor: SacColors.backgroundHC,
    );
