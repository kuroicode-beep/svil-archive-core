// sprint14_integration_test.dart — MCP archive integration 회귀 테스트

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final repoRoot = p.normalize(p.join(Directory.current.path, '..', '..'));
  final sidecarRoot = p.join(repoRoot, 'mcp', 'sidecar');
  final mcpConfig = File(p.join(repoRoot, '.cursor', 'mcp.json'));

  test('sidecar archive modules exist in source tree', () {
    expect(File(p.join(sidecarRoot, 'src', 'archive', 'archive_service.ts')).existsSync(), isTrue);
    expect(File(p.join(sidecarRoot, 'src', 'tools', 'handler.ts')).existsSync(), isTrue);
    expect(File(p.join(sidecarRoot, 'test', 'archive.test.ts')).existsSync(), isTrue);
  });

  test('sidecar package includes better-sqlite3 dependency', () async {
    final pubspec = await File(p.join(sidecarRoot, 'package.json')).readAsString();
    expect(pubspec, contains('better-sqlite3'));
    expect(pubspec, isNot(contains('get_workspace_status')));
    final definitions = await File(p.join(sidecarRoot, 'src', 'tools', 'definitions.ts')).readAsString();
    expect(definitions, contains('get_workspace_status'));
  });

  test('cursor mcp config references sac-archive sidecar', () async {
    expect(await mcpConfig.exists(), isTrue);
    final content = await mcpConfig.readAsString();
    expect(content, contains('sac-archive'));
    expect(content, contains('SAC_WORKSPACE_ROOT'));
    expect(content.contains('mcp/sidecar') || content.contains('mcp\\\\sidecar'), isTrue);
  });

  test('handler no longer returns Phase 1 stub message', () async {
    final handler = await File(p.join(sidecarRoot, 'src', 'tools', 'handler.ts')).readAsString();
    expect(handler, isNot(contains('Phase 1 Stub')));
    expect(handler, contains('QUEUE_APPROVAL_REQUIRED'));
  });

  test('Sprint 13 startup fix keeps initializeEarly in main', () async {
    final mainDart = await File(p.join(repoRoot, 'app', 'flutter_app', 'lib', 'main.dart')).readAsString();
    expect(mainDart, contains('initializeEarly'));
    expect(mainDart, isNot(contains('desktopShell.initialize()')));
  });

  test('package_windows_rc rebuilds and verifies better-sqlite3 native binding', () async {
    final script = await File(p.join(repoRoot, 'scripts', 'package_windows_rc.ps1')).readAsString();
    expect(script, contains('npm rebuild better-sqlite3'));
    expect(script, contains('better_sqlite3.node'));
    expect(script, isNot(contains('npm ci --ignore-scripts')));
    expect(script, isNot(contains('npm ci --omit=dev --ignore-scripts')));
    expect(script, contains('mcp_sidecar_native_binding_included'));
  });

  test('Sprint 14 docs use native-safe sidecar install commands', () async {
    for (final name in [
      'Codex_Verification_Request_Sprint_14.md',
      'Cursor_MCP_Setup_Sprint_14.md',
    ]) {
      final content = await File(p.join(repoRoot, 'docs', 'handoff', name)).readAsString();
      expect(content, isNot(contains('npm ci --ignore-scripts &&')));
      expect(content, anyOf(contains('npm ci &&'), contains('verify:native')));
    }
  });
}
