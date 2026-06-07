// theme_service_impl.dart — 테마/고대비 설정 영속화

import 'package:sqflite/sqflite.dart';

import '../../domain/models/settings.dart';
import '../../domain/services/settings_service.dart';
import '../db/database_service_impl.dart';

class ThemeServiceImpl implements ThemeService {
  final DatabaseServiceImpl _databaseService;

  ThemeServiceImpl({required DatabaseServiceImpl databaseService})
      : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<ThemeSettings> getThemeSettings() async {
    final rows = await _db.query('app_settings');
    final map = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    return ThemeSettings(
      theme: _parseTheme(map['theme_mode']),
      highContrastEnabled: map['high_contrast_enabled'] == 'true',
      fontSizeBase: double.tryParse(map['font_size_base'] ?? '') ?? 16.0,
    );
  }

  @override
  Future<void> applyTheme(AppTheme theme) async {
    final current = await getThemeSettings();
    await _saveTheme(current.copyWith(theme: theme));
  }

  @override
  Future<void> toggleHighContrast(bool enabled) async {
    final current = await getThemeSettings();
    await _saveTheme(current.copyWith(highContrastEnabled: enabled));
  }

  /// app_settings에 테마 설정을 저장한다.
  Future<void> _saveTheme(ThemeSettings settings) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final entries = <Map<String, String>>[
      {'key': 'theme_mode', 'value': settings.theme.name},
      {
        'key': 'high_contrast_enabled',
        'value': settings.highContrastEnabled.toString(),
      },
      {'key': 'font_size_base', 'value': settings.fontSizeBase.toString()},
    ];
    for (final entry in entries) {
      await _db.insert(
        'app_settings',
        {
          'key': entry['key'],
          'value': entry['value'],
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// 저장된 theme_mode 문자열을 AppTheme으로 변환한다.
  AppTheme _parseTheme(String? raw) {
    return AppTheme.values.firstWhere(
      (theme) => theme.name == raw,
      orElse: () => AppTheme.light,
    );
  }
}
