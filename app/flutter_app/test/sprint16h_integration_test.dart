// sprint16h_integration_test.dart — Sprint 16H UI/Settings/Ollama hotfix 통합 테스트

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/services/download_watcher_service_impl.dart';
import 'package:sac_app/data/services/ollama_adapter.dart';
import 'package:sac_app/domain/models/dashboard.dart';
import 'package:sac_app/domain/services/local_ai_service.dart';
void main() {
  group('sprint16h integration', () {
    late Directory tempDir;
    late Directory downloadsDir;
    late Directory altWatchDir;
    late SacContainer container;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sac_sprint16h_test_');
      downloadsDir = await Directory(p.join(tempDir.path, 'Downloads')).create(recursive: true);
      altWatchDir = await Directory(p.join(tempDir.path, 'AltWatch')).create(recursive: true);
      container = await SacContainer.create(registryDirectory: tempDir.path);
    });

    tearDown(() async {
      await container.disposeForTest();
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    Future<void> bindWorkspace() async {
      final workspace = await container.workspaceService.createWorkspace(
        name: 'Sprint16H WS',
        rootPath: p.join(tempDir.path, 'SAC S16H'),
      );
      await container.bindWorkspace(workspace);
    }

    test('download watch folder saves and reloads after restart simulation', () async {
      await bindWorkspace();
      final current = await container.settingsService.getSettings();
      await container.settingsService.saveSettings(
        current.copyWith(
          downloads: current.downloads.copyWith(
            folderPath: altWatchDir.path,
            includeSubfolders: true,
          ),
        ),
      );

      final reloaded = await container.settingsService.getSettings();
      expect(reloaded.downloads.folderPath, altWatchDir.path);
      expect(reloaded.downloads.includeSubfolders, isTrue);
    });

    test('download watch folder resets to default Downloads path', () async {
      await bindWorkspace();
      final current = await container.settingsService.getSettings();
      await container.settingsService.saveSettings(
        current.copyWith(
          downloads: current.downloads.copyWith(folderPath: altWatchDir.path),
        ),
      );
      await container.settingsService.saveSettings(
        current.copyWith(downloads: current.downloads.copyWith(folderPath: '')),
      );
      final reloaded = await container.settingsService.getSettings();
      expect(reloaded.downloads.folderPath, isEmpty);
      expect(
        container.downloadWatcherService.resolvedFolderPath,
        DownloadWatcherServiceImpl.resolveDefaultDownloadsFolder(),
      );
    });

    test('applyDownloadWatcherSettings restarts watcher on folder change', () async {
      await bindWorkspace();
      final current = await container.settingsService.getSettings();
      final enabled = current.downloads.copyWith(enabled: true, folderPath: downloadsDir.path);
      await container.settingsService.saveSettings(current.copyWith(downloads: enabled));
      await container.applyDownloadWatcherSettings(enabled);
      expect(container.downloadWatcherService.isRunning, isTrue);
      expect(container.downloadWatcherService.resolvedFolderPath, downloadsDir.path);

      final moved = enabled.copyWith(folderPath: altWatchDir.path);
      await container.settingsService.saveSettings(current.copyWith(downloads: moved));
      await container.applyDownloadWatcherSettings(moved);
      expect(container.downloadWatcherService.resolvedFolderPath, altWatchDir.path);
    });

    test('ollama endpoint saves and loads', () async {
      await bindWorkspace();
      final current = await container.settingsService.getSettings();
      await container.settingsService.saveSettings(
        current.copyWith(ollamaEndpoint: 'http://127.0.0.1:11435'),
      );
      final reloaded = await container.settingsService.getSettings();
      expect(reloaded.ollamaEndpoint, 'http://127.0.0.1:11435');
    });

    test('ollama model selection saves and loads', () async {
      await bindWorkspace();
      final current = await container.settingsService.getSettings();
      await container.settingsService.saveSettings(
        current.copyWith(ollamaModel: 'llama3:latest'),
      );
      final reloaded = await container.settingsService.getSettings();
      expect(reloaded.ollamaModel, 'llama3:latest');
    });

    test('ollama adapter returns empty models safely on connection failure', () async {
      final adapter = OllamaAdapter(
        baseUrl: 'http://127.0.0.1:59998',
        timeout: const Duration(milliseconds: 200),
      );
      final status = await adapter.checkStatus();
      expect(status.state, isNot(LocalAiConnectionState.connected));
      final models = await adapter.listModels();
      expect(models, isEmpty);
    });

    test('local ai service mock returns installed model list', () async {
      final service = _MockLocalAiService();
      final models = await service.listModels();
      expect(models.map((m) => m.name), containsAll(['llama3:latest', 'mistral:7b']));
    });

    test('selected ollama model missing from list is detectable', () async {
      await bindWorkspace();
      final current = await container.settingsService.getSettings();
      await container.settingsService.saveSettings(
        current.copyWith(ollamaModel: 'removed-model:old'),
      );
      final models = await container.localAiService.listModels();
      final names = models.map((m) => m.name).toSet();
      final reloaded = await container.settingsService.getSettings();
      expect(names.contains(reloaded.ollamaModel), isFalse);
    });

    test('download settings toggle save keeps persisted value without full reload flag', () async {
      await bindWorkspace();
      final current = await container.settingsService.getSettings();
      expect(current.downloads.enabled, isFalse);
      await container.settingsService.saveSettings(
        current.copyWith(downloads: current.downloads.copyWith(enabled: true)),
      );
      final reloaded = await container.settingsService.getSettings();
      expect(reloaded.downloads.enabled, isTrue);
    });

    test('git sync toggle save keeps persisted value', () async {
      await bindWorkspace();
      final current = await container.settingsService.getSettings();
      await container.settingsService.saveSettings(
        current.copyWith(gitSync: current.gitSync.copyWith(enabled: true)),
      );
      final reloaded = await container.settingsService.getSettings();
      expect(reloaded.gitSync.enabled, isTrue);
    });
  });
}

/// Ollama tags API 성공 응답을 흉내 내는 LocalAiService mock.
class _MockLocalAiService implements LocalAiService {
  @override
  Future<LocalAiStatus> checkStatus() async => const LocalAiStatus(
        state: LocalAiConnectionState.connected,
        label: '연결됨',
        endpoint: 'http://127.0.0.1:11434',
      );

  @override
  Future<List<LocalAiModel>> listModels() async => const [
        LocalAiModel(name: 'llama3:latest', family: 'llama'),
        LocalAiModel(name: 'mistral:7b'),
      ];
}
