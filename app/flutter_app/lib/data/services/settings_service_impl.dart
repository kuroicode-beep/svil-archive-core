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
  }
}
