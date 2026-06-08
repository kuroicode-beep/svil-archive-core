// sprint12b_integration_test.dart — Windows portable MCP sidecar 패키징 통합 테스트

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/domain/models/rc_build_approval.dart';
import 'package:sac_app/domain/utils/mcp_sidecar_path_resolver.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sac_sprint12b_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('packaged sidecar path resolves relative to executable directory', () async {
    final distDir = Directory(p.join(tempDir.path, 'mcp', 'sidecar', 'dist'));
    await distDir.create(recursive: true);
    await File(p.join(distDir.path, 'index.js')).writeAsString('// test');

    final fakeExe = p.join(tempDir.path, 'sac_app.exe');
    await File(fakeExe).writeAsString('');

    final resolution = resolveMcpSidecarPath(
      executablePath: fakeExe,
      workingDirectory: tempDir.path,
    );

    expect(resolution.source, McpSidecarPathSource.packaged);
    expect(resolution.distPath, distDir.path);
    expect(mcpSidecarStatusLabel(resolution), contains('패키지 내 sidecar'));
  });

  test('dev fallback path is used when packaged sidecar is missing', () async {
    final devDist = Directory(p.join(tempDir.path, 'mcp', 'sidecar', 'dist'));
    await devDist.create(recursive: true);
    await File(p.join(devDist.path, 'index.js')).writeAsString('// dev');

    final fakeExe = p.join(tempDir.path, 'nested', 'sac_app.exe');
    await Directory(p.dirname(fakeExe)).create(recursive: true);
    await File(fakeExe).writeAsString('');

    final resolution = resolveMcpSidecarPath(
      executablePath: fakeExe,
      workingDirectory: tempDir.path,
    );

    expect(resolution.source, McpSidecarPathSource.devFallback);
    expect(resolution.distPath, devDist.path);
    expect(mcpSidecarStatusLabel(resolution), contains('개발 경로 fallback'));
  });

  test('not found when no sidecar dist exists', () {
    final resolution = resolveMcpSidecarPath(
      executablePath: p.join(tempDir.path, 'sac_app.exe'),
      workingDirectory: p.join(tempDir.path, 'empty'),
    );

    expect(resolution.source, McpSidecarPathSource.notFound);
    expect(resolution.distPath, isNull);
    expect(mcpSidecarStatusLabel(resolution), 'sidecar 빌드 없음');
  });

  test('portable BUILD_MANIFEST.json validates sidecar flags without secrets', () {
    final manifest = <String, dynamic>{
      'version': 'v0.1.0-rc.1',
      'commit': '9ec7e43',
      'platform': 'windows-x64',
      'package_type': 'portable-zip',
      'mcp_sidecar_included': true,
      'mcp_sidecar_path': 'mcp/sidecar',
      'mcp_sidecar_build': 'pass',
      'mcp_sidecar_runtime': 'local-stdio',
      'external_api_enabled': false,
      'remote_mcp_enabled': false,
    };

    expect(validatePortableBuildManifest(manifest), isTrue);
    expect(manifest.containsKey('api_key'), isFalse);
    expect(manifest.containsKey('token'), isFalse);
  });

  test('portable package folder includes mcp/sidecar when built by script output', () {
    final repoRoot = p.normalize(p.join(Directory.current.path, '..', '..'));
    final binRoot = Directory(p.join(repoRoot, 'bin', 'windows'));
    if (!binRoot.existsSync()) {
      return;
    }

    final packages = binRoot
        .listSync()
        .whereType<Directory>()
        .where((d) => p.basename(d.path).contains('sac_v0.1.0-rc.1_windows_x64'))
        .toList();
    if (packages.isEmpty) {
      return;
    }

    final latest = packages.last;
    final sidecarDist = File(p.join(latest.path, 'mcp', 'sidecar', 'dist', 'index.js'));
    final manifestFile = File(p.join(latest.path, 'BUILD_MANIFEST.json'));
    final installFile = File(p.join(latest.path, 'INSTALL.txt'));

    expect(sidecarDist.existsSync(), isTrue, reason: 'mcp/sidecar/dist/index.js missing');
    expect(manifestFile.existsSync(), isTrue);

    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    expect(validatePortableBuildManifest(manifest), isTrue);

    final installText = installFile.readAsStringSync();
    expect(installText, contains('MCP sidecar'));
    expect(installText, contains('remote MCP'));
    expect(installText.toLowerCase(), isNot(contains('api_key')));
  });

  test('MCP bridge reports local-only with remote exposure disabled', () async {
    final container = await SacContainer.create(registryDirectory: tempDir.path);
    addTearDown(() => container.disposeForTest());

    final workspace = await container.workspaceService.createWorkspace(
      name: 'S12B MCP',
      rootPath: p.join(tempDir.path, 'mcp_ws'),
    );
    await container.bindWorkspace(workspace);

    final status = await container.mcpBridgeStatusService.checkStatus();
    expect(status.localOnly, isTrue);
    expect(status.remoteExposureEnabled, isFalse);

    final settings = await container.settingsService.getSettings();
    expect(settings.externalApiEnabled, isFalse);
  });

  test('Sprint 12 regression — release approval policy still blocks smoke pending', () async {
    final container = await SacContainer.create(registryDirectory: tempDir.path);
    addTearDown(() => container.disposeForTest());

    final workspace = await container.workspaceService.createWorkspace(
      name: 'S12B',
      rootPath: p.join(tempDir.path, 'ws'),
    );
    await container.bindWorkspace(workspace);

    final summary = await container.releaseApprovalService.evaluateAndPersist();
    expect(summary.status, isNot(ReleaseApprovalStatus.readyForApproval));
  });
}
