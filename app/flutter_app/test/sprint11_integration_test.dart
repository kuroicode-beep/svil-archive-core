// sprint11_integration_test.dart — RC Finalization / Release Notes 통합 테스트

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/db/migrations.dart';
import 'package:sac_app/data/services/report_consistency_service_impl.dart';
import 'package:sac_app/domain/models/rc_finalization.dart';
import 'package:sac_app/domain/models/smoke_test_record.dart';
import 'package:sac_app/domain/services/archive_service.dart';
import 'package:sac_app/domain/utils/rc_finalization_policy.dart';

void main() {
  late Directory tempDir;
  late SacContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sac_sprint11_test_');
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
      name: 'Sprint11 WS',
      rootPath: p.join(tempDir.path, 'SAC S11'),
    );
    await container.bindWorkspace(workspace);
  }

  Future<void> recordVerificationSet({String sprintCommit = '1db8bfd', int testCount = 126}) async {
    final svc = container.verificationPassRecordService;
    await svc.recordPass(
      checkType: 'analyze',
      source: 'auto',
      verifiedHeadCommit: '9c47b7e',
      verifiedSprintCommit: sprintCommit,
    );
    await svc.recordPass(
      checkType: 'test',
      source: 'auto',
      testCount: testCount,
      verifiedHeadCommit: '9c47b7e',
      verifiedSprintCommit: sprintCommit,
    );
    await svc.recordPass(
      checkType: 'sidecar_build',
      source: 'auto',
      verifiedHeadCommit: '9c47b7e',
      verifiedSprintCommit: sprintCommit,
    );
  }

  Future<void> passSmoke(String platform) async {
    final record = await container.smokeTestRecordService.createRecord(
      platform: platform,
      checklistName: platform == 'macOS' ? 'macos_smoke' : 'windows_smoke',
      notes: 'Sprint11 test pass',
    );
    await container.smokeTestRecordService.updateRecord(
      id: record.id,
      status: SmokeTestStatus.passed,
      notes: 'PASS',
    );
  }

  test('migration v9 creates verification_pass_records table', () async {
    await bindWorkspace();
    expect(await container.databaseService.getSchemaVersion(), kSacSchemaVersion);
    final db = container.databaseService.requireDatabase();
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final names = tables.map((r) => r['name'] as String).toSet();
    expect(names.contains('verification_pass_records'), isTrue);
  });

  test('isReadyForRc false when smoke pending without verification', () async {
    await bindWorkspace();
    final summary = await container.releaseReadinessService.evaluate();
    expect(summary.rcFinalizationStatus, isNot(RcFinalizationStatus.ready));
    expect(summary.isReadyForRc, isFalse);
  });

  test('auto verification pass with smoke pending yields warning', () async {
    await bindWorkspace();
    await recordVerificationSet();
    final summary = await container.releaseReadinessService.evaluate();
    expect(summary.rcFinalizationStatus, RcFinalizationStatus.warning);
    expect(summary.isReadyForRc, isFalse);
    expect(summary.rcStatusLabel, contains('smoke'));
  });

  test('auto verification pass with both smoke pass yields ready', () async {
    await bindWorkspace();
    await recordVerificationSet();
    await passSmoke('macOS');
    await passSmoke('Windows');
    final summary = await container.releaseReadinessService.evaluate();
    expect(summary.rcFinalizationStatus, RcFinalizationStatus.ready);
    expect(summary.isReadyForRc, isTrue);
    expect(summary.rcStatusLabel, contains('배포 후보'));
  });

  test('verification commit mismatch yields warning not ready', () async {
    await bindWorkspace();
    await recordVerificationSet(sprintCommit: 'deadbeef');
    await passSmoke('macOS');
    await passSmoke('Windows');
    final summary = await container.releaseReadinessService.evaluate();
    expect(summary.verificationCommitMismatch, isTrue);
    expect(summary.rcFinalizationStatus, RcFinalizationStatus.warning);
    expect(summary.isReadyForRc, isFalse);
  });

  test('verification pass records persist and reload', () async {
    await bindWorkspace();
    await recordVerificationSet();
    final analyze = await container.verificationPassRecordService.getLatestForType('analyze');
    final test = await container.verificationPassRecordService.getLatestForType('test');
    expect(analyze?.verifiedSprintCommit, '1db8bfd');
    expect(test?.testCount, 126);
    expect(await container.verificationPassRecordService.hasCompleteVerificationSet(), isTrue);
  });

  test('release notes export writes markdown file', () async {
    await bindWorkspace();
    await recordVerificationSet();
    final result = await container.releaseFinalizationExportService.exportReleaseNotes();
    expect(result.relativePath, contains('release_notes_v0.1_rc'));
    expect(File(result.absolutePath).existsSync(), isTrue);
    expect(result.markdown, contains('# SAC v0.1 RC Release Notes'));
  });

  test('release notes export excludes sensitive document body', () async {
    await bindWorkspace();
    await container.archiveService.createDocument(
      const CreateDocumentInput(
        title: 'SecretDoc',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: 'TOP_SECRET_PERSONAL_BODY_12345',
      ),
    );
    await recordVerificationSet();
    final result = await container.releaseFinalizationExportService.exportReleaseNotes();
    expect(result.markdown.contains('TOP_SECRET_PERSONAL_BODY_12345'), isFalse);
    expect(result.markdown.contains('API key'), isFalse);
  });

  test('known issues export writes markdown file', () async {
    await bindWorkspace();
    final result = await container.releaseFinalizationExportService.exportKnownIssues();
    expect(result.relativePath, contains('known_issues_v0.1_rc'));
    expect(result.markdown, contains('KI-001'));
    expect(result.markdown, contains('external API disabled by design'));
  });

  test('known issues export excludes secret token patterns', () async {
    await bindWorkspace();
    final result = await container.releaseFinalizationExportService.exportKnownIssues();
    expect(result.markdown.toLowerCase().contains('api_key'), isFalse);
    expect(result.markdown.toLowerCase().contains('secret_token'), isFalse);
  });

  test('tag readiness checklist export and no auto git tag', () async {
    await bindWorkspace();
    final result = await container.releaseFinalizationExportService.exportTagReadinessChecklist();
    expect(result.relativePath, contains('rc_tag_readiness_v0.1'));
    expect(result.markdown, contains('v0.1.0-rc.1'));
    expect(result.markdown, contains('Git tag는 자동 생성하지 않는다'));
    expect(result.markdown, contains('- [ ] Notion 완료보고서 작성'));
  });

  test('export status reflects generated documents', () async {
    await bindWorkspace();
    var status = await container.releaseFinalizationExportService.getExportStatus();
    expect(status.releaseNotesExported, isFalse);
    await container.releaseFinalizationExportService.exportReleaseNotes();
    await container.releaseFinalizationExportService.exportKnownIssues();
    status = await container.releaseFinalizationExportService.getExportStatus();
    expect(status.releaseNotesExported, isTrue);
    expect(status.knownIssuesExported, isTrue);
  });

  test('dashboard includes rc finalization summary', () async {
    await bindWorkspace();
    await recordVerificationSet();
    final dashboard = await container.dashboardService.getDashboardSummary();
    expect(dashboard.rcFinalization.statusLabel, isNotEmpty);
    expect(dashboard.rcFinalization.readiness.items, isNotEmpty);
    expect(dashboard.rcFinalization.suggestedTag, 'v0.1.0-rc.1');
  });

  test('privacy includes release export policy labels', () async {
    await bindWorkspace();
    final privacy = await container.privacyService.getPrivacySummary();
    expect(privacy.releaseExportPolicyLabel, contains('개인 본문'));
    expect(privacy.knownIssuesPolicyLabel, contains('remote MCP'));
  });

  test('computeRcFinalizationStatus ready when all pass', () {
    final status = computeRcFinalizationStatus(
      failCount: 0,
      buildFailed: false,
      macSmokeStatus: SmokeTestStatus.passed,
      winSmokeStatus: SmokeTestStatus.passed,
      verificationComplete: true,
      verificationCommitMismatch: false,
    );
    expect(status, RcFinalizationStatus.ready);
  });

  test('computeRcFinalizationStatus blocked on fail count', () {
    final status = computeRcFinalizationStatus(
      failCount: 1,
      buildFailed: false,
      macSmokeStatus: SmokeTestStatus.passed,
      winSmokeStatus: SmokeTestStatus.passed,
      verificationComplete: true,
      verificationCommitMismatch: false,
    );
    expect(status, RcFinalizationStatus.blocked);
  });

  test('computeRcFinalizationStatus warning on smoke pending', () {
    final status = computeRcFinalizationStatus(
      failCount: 0,
      buildFailed: false,
      macSmokeStatus: SmokeTestStatus.pending,
      winSmokeStatus: SmokeTestStatus.passed,
      verificationComplete: true,
      verificationCommitMismatch: false,
    );
    expect(status, RcFinalizationStatus.warning);
  });

  test('computeRcFinalizationStatus unknown without verification', () {
    final status = computeRcFinalizationStatus(
      failCount: 0,
      buildFailed: false,
      macSmokeStatus: SmokeTestStatus.passed,
      winSmokeStatus: SmokeTestStatus.passed,
      verificationComplete: false,
      verificationCommitMismatch: false,
    );
    expect(status, RcFinalizationStatus.unknown);
  });

  test('smoke failed status yields blocked rc finalization', () async {
    await bindWorkspace();
    await recordVerificationSet();
    final record = await container.smokeTestRecordService.createRecord(
      platform: 'Windows',
      checklistName: 'windows_smoke',
    );
    await container.smokeTestRecordService.updateRecord(
      id: record.id,
      status: SmokeTestStatus.failed,
      notes: 'fail',
    );
    await passSmoke('macOS');
    final summary = await container.releaseReadinessService.evaluate();
    expect(summary.rcFinalizationStatus, RcFinalizationStatus.blocked);
    expect(summary.isReadyForRc, isFalse);
  });

  test('report manifest still includes Sprint 10', () {
    expect(kSprintReportCommitManifest['Sprint 10'], '1db8bfd');
  });

  test('Sprint 10 readiness evaluate still works after Sprint 11 changes', () async {
    await bindWorkspace();
    final summary = await container.releaseReadinessService.evaluate();
    expect(summary.items.any((i) => i.category == 'verification'), isTrue);
    expect(summary.items.any((i) => i.label == 'macOS smoke'), isTrue);
  });
}
