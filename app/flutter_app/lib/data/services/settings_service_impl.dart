// settings_service_impl.dart — app_settings 테이블 기반 설정 저장

import 'package:sqflite/sqflite.dart';

import '../../domain/models/settings.dart';
import '../../domain/services/settings_service.dart';
import '../db/database_service_impl.dart';

class SettingsServiceImpl implements SettingsService {
  final DatabaseServiceImpl _databaseService;

  SettingsServiceImpl({required DatabaseServiceImpl databaseService})
      : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<AppSettings> getSettings() async {
    final rows = await _db.query('app_settings');
    final map = {for (final row in rows) row['key'] as String: row['value'] as String};
    return AppSettings(
      workspaceId: map['active_workspace_id'] ?? '',
      theme: const ThemeSettings(),
      tts: const TtsSettings(),
      mcpEnabled: map['mcp_enabled'] == 'true',
      ollamaEndpoint: map['ollama_endpoint'] ?? 'http://127.0.0.1:11434',
      externalApiEnabled: map['external_api_enabled'] == 'true',
      autoStartSidecar: map['auto_start_sidecar'] == 'true',
      closeToTray: map['close_to_tray'] != 'false',
      startWithWindows: map['start_with_windows'] == 'true',
      registeredAutostartExePath: map['registered_autostart_exe_path'],
    );
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert(
      'app_settings',
      {
        'key': 'active_workspace_id',
        'value': settings.workspaceId,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _db.insert(
      'app_settings',
      {
        'key': 'mcp_enabled',
        'value': settings.mcpEnabled.toString(),
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _db.insert(
      'app_settings',
      {
        'key': 'ollama_endpoint',
        'value': settings.ollamaEndpoint,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _db.insert(
      'app_settings',
      {
        'key': 'external_api_enabled',
        'value': settings.externalApiEnabled.toString(),
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _persistKey('auto_start_sidecar', settings.autoStartSidecar.toString(), now);
    await _persistKey('close_to_tray', settings.closeToTray.toString(), now);
    await _persistKey('start_with_windows', settings.startWithWindows.toString(), now);
    if (settings.registeredAutostartExePath == null) {
      await _db.delete('app_settings', where: 'key = ?', whereArgs: ['registered_autostart_exe_path']);
    } else {
      await _persistKey('registered_autostart_exe_path', settings.registeredAutostartExePath!, now);
    }
  }

  /// 단일 app_settings 키를 저장한다.
  Future<void> _persistKey(String key, String value, String updatedAt) async {
    await _db.insert(
      'app_settings',
      {'key': key, 'value': value, 'updated_at': updatedAt},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
