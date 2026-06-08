// sprint10_integration_test.dart — RC / Smoke / Packaging Readiness 통합 테스트

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/db/migrations.dart';
import 'package:sac_app/data/services/report_consistency_service_impl.dart';
import 'package:sac_app/domain/models/build_environment_check.dart';
import 'package:sac_app/domain/models/release_readiness.dart';
import 'package:sac_app/domain/models/smoke_test_record.dart';
void main() {
  late Directory tempDir;
  late SacContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sac_sprint10_test_');
    container = await SacContainer.create(registryDirectory: tempDir.path);
  });

  tearDown(() async {
    await container.disposeForTest();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> bindWorkspace() async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Sprint10 WS',
      rootPath: p.join(tempDir.path, 'SAC S10'),
    );
    await container.bindWorkspace(workspace);
  }

  test('migration v8 creates release readiness tables', () async {
    await bindWorkspace();
    expect(await container.databaseService.getSchemaVersion(), kSacSchemaVersion);
    final db = container.databaseService.requireDatabase();
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final names = tables.map((r) => r['name'] as String).toSet();
    expect(names.contains('release_readiness_checks'), isTrue);
    expect(names.contains('build_environment_checks'), isTrue);
  });

  test('kDefaultWindowsSmokeChecklist has expected items', () {
    expect(kDefaultWindowsSmokeChecklist.length, greaterThanOrEqualTo(10));
    expect(kDefaultWindowsSmokeChecklist, contains('Settings / RC 화면 표시'));
  });

  test('settings saves ollama endpoint', () async {
    await bindWorkspace();
    final settings = await container.settingsService.getSettings();
    await container.settingsService.saveSettings(
      settings.copyWith(ollamaEndpoint: 'http://127.0.0.1:11435'),
    );
    final saved = await container.settingsService.getSettings();
    expect(saved.ollamaEndpoint, 'http://127.0.0.1:11435');
  });

  test('settings external API defaults to false', () async {
    await bindWorkspace();
    final settings = await container.settingsService.getSettings();
    expect(settings.externalApiEnabled, isFalse);
  });

  test('build environment check runs and persists', () async {
    await bindWorkspace();
    final checks = await container.buildEnvironmentCheckService.runChecks();
    expect(checks.length, greaterThanOrEqualTo(4));
    expect(checks.any((c) => c.checkName == 'schema_version'), isTrue);
    expect(checks.firstWhere((c) => c.checkName == 'schema_version').status, BuildCheckStatus.pass);

    final latest = await container.buildEnvironmentCheckService.getLatestChecks();
    expect(latest.length, checks.length);
  });

  test('workspace writable check passes after bind', () async {
    await bindWorkspace();
    final checks = await container.buildEnvironmentCheckService.runChecks();
    final writable = checks.firstWhere((c) => c.checkName == 'workspace_writable');
    expect(writable.status, BuildCheckStatus.pass);
  });

  test('release readiness evaluate returns summary', () async {
    await bindWorkspace();
    final summary = await container.releaseReadinessService.evaluate();
    expect(summary.items, isNotEmpty);
    final unknownCount = summary.items
        .where((i) => i.status == ReadinessItemStatus.unknown)
        .length;
    expect(
      summary.passCount + summary.warnCount + summary.failCount + unknownCount,
      summary.items.length,
    );
    expect(summary.checkedAt, isNotNull);
  });

  test('release readiness getLatestSummary after evaluate', () async {
    await bindWorkspace();
    await container.releaseReadinessService.evaluate();
    final latest = await container.releaseReadinessService.getLatestSummary();
    expect(latest, isNotNull);
    expect(latest!.items, isNotEmpty);
  });

  test('external API off yields pass in readiness', () async {
    await bindWorkspace();
    final summary = await container.releaseReadinessService.evaluate();
    final apiItem = summary.items.firstWhere((i) => i.label == '외부 API 기본 OFF');
    expect(apiItem.status, ReadinessItemStatus.pass);
  });

  test('mcp local-only yields pass in readiness', () async {
    await bindWorkspace();
    final summary = await container.releaseReadinessService.evaluate();
    final mcpItem = summary.items.firstWhere((i) => i.label == 'MCP local-only');
    expect(mcpItem.status, ReadinessItemStatus.pass);
  });

  test('smoke test create and update pass for macOS', () async {
    await bindWorkspace();
    final record = await container.smokeTestRecordService.createRecord(
      platform: 'macOS',
      checklistName: 'SAC macOS Smoke',
      status: SmokeTestStatus.pending,
    );
    await container.smokeTestRecordService.updateRecord(
      id: record.id,
      status: SmokeTestStatus.passed,
    );
    final latest = await container.smokeTestRecordService.getLatestForPlatform('macOS');
    expect(latest?.status, SmokeTestStatus.passed);
  });

  test('smoke test create and update fail for Windows', () async {
    await bindWorkspace();
    final record = await container.smokeTestRecordService.createRecord(
      platform: 'Windows',
      checklistName: 'SAC Windows Smoke',
      status: SmokeTestStatus.pending,
    );
    await container.smokeTestRecordService.updateRecord(
      id: record.id,
      status: SmokeTestStatus.failed,
      notes: 'test failure',
    );
    final latest = await container.smokeTestRecordService.getLatestForPlatform('Windows');
    expect(latest?.status, SmokeTestStatus.failed);
    expect(latest?.notes, 'test failure');
  });

  test('smoke skipped status updates correctly', () async {
    await bindWorkspace();
    final record = await container.smokeTestRecordService.createRecord(
      platform: 'Windows',
      checklistName: 'skip test',
    );
    await container.smokeTestRecordService.updateRecord(
      id: record.id,
      status: SmokeTestStatus.skipped,
    );
    final latest = await container.smokeTestRecordService.getLatestForPlatform('Windows');
    expect(latest?.status, SmokeTestStatus.skipped);
  });

  test('passed macOS smoke improves readiness smoke item', () async {
    await bindWorkspace();
    await container.smokeTestRecordService.createRecord(
      platform: 'macOS',
      checklistName: 'pass test',
      status: SmokeTestStatus.passed,
    );
    final summary = await container.releaseReadinessService.evaluate();
    final macItem = summary.items.firstWhere((i) => i.label == 'macOS smoke');
    expect(macItem.status, ReadinessItemStatus.pass);
  });

  test('release checklist export writes markdown file', () async {
    await bindWorkspace();
    await container.releaseReadinessService.evaluate();
    final result = await container.releaseChecklistExportService.exportToFile();
    expect(result.relativePath, contains('release_checklist_'));
    expect(result.relativePath, startsWith('.sac/exports/'));
    final file = File(result.absolutePath);
    expect(await file.exists(), isTrue);
    final content = await file.readAsString();
    expect(content, contains('# SAC Release Checklist'));
    expect(content, contains('## Windows Checklist'));
    expect(content, contains('## macOS Checklist'));
  });

  test('dashboard includes release readiness summary', () async {
    await bindWorkspace();
    final summary = await container.dashboardService.getDashboardSummary();
    expect(summary.releaseReadiness.items, isNotEmpty);
    expect(summary.windowsSmokeStatus, isNull);
    expect(summary.macSmokeStatus, isNull);
  });

  test('dashboard shows smoke status after record', () async {
    await bindWorkspace();
    await container.smokeTestRecordService.createRecord(
      platform: 'Windows',
      checklistName: 'dash test',
      status: SmokeTestStatus.passed,
    );
    final summary = await container.dashboardService.getDashboardSummary();
    expect(summary.windowsSmokeStatus, SmokeTestStatus.passed);
  });

  test('privacy summary includes release blocking count', () async {
    await bindWorkspace();
    await container.releaseReadinessService.evaluate();
    final privacy = await container.privacyService.getPrivacySummary();
    expect(privacy.releaseReadiness, isNotNull);
    expect(privacy.releaseBlockingCount, privacy.releaseReadiness!.failCount);
  });

  test('report manifest includes Sprint 09 and Sprint 10', () {
    expect(kSprintReportCommitManifest.containsKey('Sprint 09'), isTrue);
    expect(kSprintReportCommitManifest['Sprint 09'], 'cd684a2');
    expect(kSprintReportCommitManifest.containsKey('Sprint 10'), isTrue);
    expect(kSprintReportCommitManifest['Sprint 10'], '1db8bfd');
  });

  test('ollama endpoint update refreshes local AI service', () async {
    await bindWorkspace();
    container.updateOllamaEndpoint('http://127.0.0.1:19999');
    final status = await container.localAiService.checkStatus();
    expect(status.endpoint, 'http://127.0.0.1:19999');
    expect(status.state.name, isNotEmpty);
  });

  test('release readiness isReadyForRc false when conflict exists', () async {
    await bindWorkspace();
    final summary = await container.releaseReadinessService.evaluate();
    final conflictItem = summary.items.firstWhere((i) => i.label == 'sync conflict');
    if (conflictItem.status == ReadinessItemStatus.fail) {
      expect(summary.isReadyForRc, isFalse);
    } else {
      expect(conflictItem.status, ReadinessItemStatus.pass);
    }
  });
}
