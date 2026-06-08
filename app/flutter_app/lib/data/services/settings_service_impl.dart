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
      gitSync: _readGitSync(map),
      downloads: _readDownloads(map),
    );
  }

  /// Git Sync 설정을 app_settings 맵에서 복원한다.
  GitSyncSettings _readGitSync(Map<String, String> map) {
    const defaults = GitSyncSettings();
    return GitSyncSettings(
      enabled: map['git_sync_enabled'] == 'true',
      repoUrl: map['git_repo_url'] ?? defaults.repoUrl,
      branch: map['git_branch']?.isNotEmpty == true ? map['git_branch']! : defaults.branch,
      remoteName:
          map['git_remote_name']?.isNotEmpty == true ? map['git_remote_name']! : defaults.remoteName,
      autoCommit: map['git_auto_commit'] == 'true',
      autoPush: map['git_auto_push'] == 'true',
      syncIntervalMinutes:
          int.tryParse(map['git_sync_interval_minutes'] ?? '') ?? defaults.syncIntervalMinutes,
    );
  }

  /// 다운로드 감시 설정을 app_settings 맵에서 복원한다.
  DownloadWatcherSettings _readDownloads(Map<String, String> map) {
    const defaults = DownloadWatcherSettings();
    final prefixCsv = map['downloads_prefixes'];
    final prefixes = (prefixCsv == null || prefixCsv.trim().isEmpty)
        ? defaults.prefixes
        : prefixCsv.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return DownloadWatcherSettings(
      enabled: map['downloads_watch_enabled'] == 'true',
      folderPath: map['downloads_folder_path'] ?? defaults.folderPath,
      prefixes: prefixes,
      includeSubfolders: map['downloads_include_subfolders'] == 'true',
      autoImport: map['downloads_auto_import'] == 'true',
      scanIntervalMinutes:
          int.tryParse(map['downloads_scan_interval_minutes'] ?? '') ?? defaults.scanIntervalMinutes,
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
    await _persistGitSync(settings.gitSync, now);
    await _persistDownloads(settings.downloads, now);
  }

  /// Git Sync 설정을 app_settings에 저장한다.
  Future<void> _persistGitSync(GitSyncSettings git, String now) async {
    await _persistKey('git_sync_enabled', git.enabled.toString(), now);
    await _persistKey('git_repo_url', git.repoUrl, now);
    await _persistKey('git_branch', git.branch, now);
    await _persistKey('git_remote_name', git.remoteName, now);
    await _persistKey('git_auto_commit', git.autoCommit.toString(), now);
    await _persistKey('git_auto_push', git.autoPush.toString(), now);
    await _persistKey('git_sync_interval_minutes', git.syncIntervalMinutes.toString(), now);
  }

  /// 다운로드 감시 설정을 app_settings에 저장한다.
  Future<void> _persistDownloads(DownloadWatcherSettings dl, String now) async {
    await _persistKey('downloads_watch_enabled', dl.enabled.toString(), now);
    await _persistKey('downloads_folder_path', dl.folderPath, now);
    await _persistKey('downloads_prefixes', dl.prefixes.join(','), now);
    await _persistKey('downloads_include_subfolders', dl.includeSubfolders.toString(), now);
    await _persistKey('downloads_auto_import', dl.autoImport.toString(), now);
    await _persistKey('downloads_scan_interval_minutes', dl.scanIntervalMinutes.toString(), now);
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
