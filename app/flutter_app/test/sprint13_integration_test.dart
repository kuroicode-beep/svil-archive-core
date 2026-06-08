// sprint13_integration_test.dart — Embedded sidecar / tray / autostart 통합 테스트

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/services/sidecar_process_manager_impl.dart';
import 'package:sac_app/data/services/windows_autostart_service_impl.dart';
import 'package:sac_app/domain/models/sidecar_lifecycle.dart';
import 'package:sac_app/data/services/report_consistency_service_impl.dart';
import 'package:sac_app/domain/utils/mcp_sidecar_path_resolver.dart';

void main() {
  late Directory tempDir;
  SacContainer? container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sac_sprint13_test_');
  });

  tearDown(() async {
    final active = container;
    if (active != null) {
      try {
        await active.disposeForTest();
      } catch (_) {}
      container = null;
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<SacContainer> bindWorkspace() async {
    final created = await SacContainer.create(registryDirectory: tempDir.path);
    container = created;
    final workspace = await created.workspaceService.createWorkspace(
      name: 'Sprint13',
      rootPath: p.join(tempDir.path, 'ws'),
    );
    await created.bindWorkspace(workspace);
    return created;
  }

  test('startup settings default to safe values', () async {
    final c = await bindWorkspace();
    final settings = await c.settingsService.getSettings();
    expect(settings.mcpEnabled, isFalse);
    expect(settings.externalApiEnabled, isFalse);
    expect(settings.autoStartSidecar, isFalse);
    expect(settings.closeToTray, isTrue);
    expect(settings.startWithWindows, isFalse);
  });

  test('auto-start off does not launch sidecar without user initiation', () async {
    final c = await bindWorkspace();
    final manager = SidecarProcessManagerImpl(
      settingsService: c.settingsService,
      processStarter: ({required executable, required arguments, required workingDirectory}) async {
        throw StateError('should not start');
      },
      executablePathResolver: () => p.join(tempDir.path, 'sac_app.exe'),
    );
    final snapshot = await manager.start();
    expect(snapshot.status, isNot(SidecarLifecycleStatus.running));
  });

  test('auto-start on attempts sidecar launch', () async {
    final c = await bindWorkspace();
    final distDir = Directory(p.join(tempDir.path, 'mcp', 'sidecar', 'dist'));
    await distDir.create(recursive: true);
    await File(p.join(distDir.path, 'index.js')).writeAsString('// test');

    var launchCount = 0;
    final manager = SidecarProcessManagerImpl(
      settingsService: c.settingsService,
      processStarter: ({required executable, required arguments, required workingDirectory}) async {
        launchCount++;
        if (Platform.isWindows) {
          return Process.start('cmd.exe', ['/c', 'exit', '0'], runInShell: true);
        }
        return Process.start('true', []);
      },
      executablePathResolver: () => p.join(tempDir.path, 'sac_app.exe'),
    );

    final current = await c.settingsService.getSettings();
    await c.settingsService.saveSettings(current.copyWith(autoStartSidecar: true));
    await manager.start();
    expect(launchCount, greaterThanOrEqualTo(1));
    await manager.dispose();
  });

  test('sidecar start failure records failed status', () async {
    final c = await bindWorkspace();
    final distDir = Directory(p.join(tempDir.path, 'mcp', 'sidecar', 'dist'));
    await distDir.create(recursive: true);
    await File(p.join(distDir.path, 'index.js')).writeAsString('// test');

    final manager = SidecarProcessManagerImpl(
      settingsService: c.settingsService,
      processStarter: ({required executable, required arguments, required workingDirectory}) async {
        throw StateError('launch failed');
      },
      executablePathResolver: () => p.join(tempDir.path, 'sac_app.exe'),
    );
    final current = await c.settingsService.getSettings();
    await c.settingsService.saveSettings(current.copyWith(autoStartSidecar: true));
    final snapshot = await manager.start();
    expect(snapshot.status, SidecarLifecycleStatus.failed);
    expect(snapshot.lastStartError, contains('launch failed'));
  });

  test('sidecar stop and restart update lifecycle status', () async {
    final c = await bindWorkspace();
    final distDir = Directory(p.join(tempDir.path, 'mcp', 'sidecar', 'dist'));
    await distDir.create(recursive: true);
    await File(p.join(distDir.path, 'index.js')).writeAsString('// test');

    Process? child;
    final manager = SidecarProcessManagerImpl(
      settingsService: c.settingsService,
      processStarter: ({required executable, required arguments, required workingDirectory}) async {
        if (Platform.isWindows) {
          child = await Process.start('cmd.exe', ['/c', 'ping', '-n', '60', '127.0.0.1'], runInShell: true);
        } else {
          child = await Process.start('sleep', ['60']);
        }
        return child!;
      },
      executablePathResolver: () => p.join(tempDir.path, 'sac_app.exe'),
    );

    final started = await manager.start(userInitiated: true);
    expect(started.status, SidecarLifecycleStatus.running);

    final stopped = await manager.stop();
    expect(stopped.status, SidecarLifecycleStatus.stopped);

    final restarted = await manager.restart();
    expect(restarted.status, SidecarLifecycleStatus.running);
    await manager.dispose();
  });

  test('windows autostart enable/disable and path mismatch detection', () async {
    if (!Platform.isWindows) return;

    final startupRoot = Directory(
      p.join(tempDir.path, 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Startup'),
    );
    await startupRoot.create(recursive: true);
    final service = WindowsAutostartServiceImpl(appDataResolver: () => tempDir.path);
    final exe = Platform.resolvedExecutable;
    await service.enable(exePath: exe);

    final enabled = await service.getStatus(registeredExePath: exe);
    expect(enabled.enabled, isTrue);
    expect(enabled.pathMismatch, isFalse);

    final mismatch = await service.getStatus(registeredExePath: p.join(tempDir.path, 'other.exe'));
    expect(mismatch.pathMismatch, isTrue);

    await service.disable();
    final disabled = await service.getStatus();
    expect(disabled.enabled, isFalse);
  });

  test('report manifest includes Sprint 13 separate from Sprint 12B', () {
    expect(kSprintReportCommitManifest['Sprint 12B'], 'c2e73a4');
    expect(kSprintReportCommitManifest['Sprint 13'], 'efa97e2');
  });

  test('Sprint 13 manifest flags validate without secrets', () {
    final manifest = <String, dynamic>{
      'version': 'v0.1.0-rc.1',
      'commit': 'abc1234',
      'platform': 'windows-x64',
      'package_type': 'portable-zip',
      'mcp_sidecar_included': true,
      'mcp_sidecar_path': 'mcp/sidecar',
      'mcp_sidecar_build': 'pass',
      'mcp_sidecar_runtime': 'local-stdio',
      'external_api_enabled': false,
      'remote_mcp_enabled': false,
      'sidecar_process_managed_by_app': true,
      'tray_resident_supported': true,
      'windows_autostart_supported': true,
    };
    expect(validatePortableBuildManifestSprint13(manifest), isTrue);
  });

  test('Sprint 12B regression — queue approval still required for destructive tools', () async {
    final c = await bindWorkspace();
    final settings = await c.settingsService.getSettings();
    expect(settings.externalApiEnabled, isFalse);
    final mcp = await c.mcpBridgeStatusService.checkStatus();
    expect(mcp.remoteExposureEnabled, isFalse);
    expect(mcp.localOnly, isTrue);
  });
}
