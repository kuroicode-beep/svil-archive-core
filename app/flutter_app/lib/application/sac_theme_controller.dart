// sac_theme_controller.dart — 앱 전역 테마 상태 컨트롤러

import 'package:flutter/material.dart';

import '../data/services/theme_service_impl.dart';
import '../domain/models/settings.dart';
import '../ui/theme/app_theme.dart';

class SacThemeController extends ChangeNotifier {
  final ThemeServiceImpl _themeService;
  ThemeSettings _settings = const ThemeSettings();
  bool _loaded = false;

  SacThemeController(this._themeService);

  ThemeSettings get settings => _settings;
  bool get isLoaded => _loaded;
  bool get highContrastEnabled => _settings.highContrastEnabled;

  /// 저장된 테마 설정을 로드한다.
  Future<void> load() async {
    _settings = await _themeService.getThemeSettings();
    _loaded = true;
    notifyListeners();
  }

  /// 고대비 모드를 토글하고 즉시 UI에 반영한다.
  Future<void> toggleHighContrast(bool enabled) async {
    await _themeService.toggleHighContrast(enabled);
    _settings = _settings.copyWith(highContrastEnabled: enabled);
    notifyListeners();
  }

  /// 현재 설정에 맞는 MaterialApp 테마를 반환한다.
  ThemeData resolveTheme() {
    if (_settings.highContrastEnabled) {
      return buildHighContrastTheme(fontSizeBase: _settings.fontSizeBase);
    }
    switch (_settings.theme) {
      case AppTheme.dark:
      case AppTheme.custom:
        return buildDarkTheme(fontSizeBase: _settings.fontSizeBase);
      case AppTheme.highContrast:
        return buildHighContrastTheme(fontSizeBase: _settings.fontSizeBase);
      case AppTheme.light:
        return buildLightTheme(fontSizeBase: _settings.fontSizeBase);
    }
  }

  /// MaterialApp themeMode를 반환한다.
  ThemeMode resolveThemeMode() {
    if (_settings.highContrastEnabled) return ThemeMode.dark;
    return _settings.theme == AppTheme.dark ? ThemeMode.dark : ThemeMode.light;
  }
}
