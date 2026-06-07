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

/// Comfortable density 기본 텍스트 스타일을 생성한다.
TextTheme _baseTextTheme(double fontSizeBase, Brightness brightness) {
  final primary = brightness == Brightness.dark
      ? SacColors.textPrimaryDark
      : SacColors.textPrimaryLight;
  return TextTheme(
    bodyMedium: TextStyle(fontSize: fontSizeBase, color: primary),
    bodyLarge: TextStyle(fontSize: fontSizeBase + 2, color: primary),
    titleMedium: TextStyle(fontSize: fontSizeBase + 2, color: primary),
    titleLarge: TextStyle(fontSize: fontSizeBase + 6, color: primary),
    labelLarge: TextStyle(fontSize: fontSizeBase, color: primary),
  );
}

ThemeData buildLightTheme({double fontSizeBase = 16.0}) => ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: SacColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        surface: SacColors.surfaceLight,
        primary: SacColors.accentLight,
      ),
      textTheme: _baseTextTheme(fontSizeBase, Brightness.light),
    );

ThemeData buildDarkTheme({double fontSizeBase = 16.0}) => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SacColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        surface: SacColors.surfaceDark,
        primary: SacColors.accentDark,
      ),
      textTheme: _baseTextTheme(fontSizeBase, Brightness.dark),
    );

// High contrast는 저시력 기준 색상으로 강화
ThemeData buildHighContrastTheme({double fontSizeBase = 16.0}) => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SacColors.backgroundHC,
      colorScheme: const ColorScheme.dark(
        surface: SacColors.surfaceHC,
        primary: SacColors.accentHC,
        onSurface: SacColors.textPrimaryHC,
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(
          fontSize: fontSizeBase,
          color: SacColors.textPrimaryHC,
        ),
        bodyLarge: TextStyle(
          fontSize: fontSizeBase + 2,
          color: SacColors.textPrimaryHC,
        ),
        titleMedium: TextStyle(
          fontSize: fontSizeBase + 2,
          color: SacColors.textCyanHC,
        ),
        titleLarge: TextStyle(
          fontSize: fontSizeBase + 6,
          color: SacColors.textAccentHC,
        ),
        labelLarge: TextStyle(
          fontSize: fontSizeBase,
          color: SacColors.textPrimaryHC,
        ),
      ),
    );
