// sprint12_integration_test.dart — RC Build Approval / Tag Readiness 통합 테스트

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/db/migrations.dart';
import 'package:sac_app/data/services/report_consistency_service_impl.dart';
import 'package:sac_app/domain/models/rc_build_approval.dart';
import 'package:sac_app/domain/models/rc_finalization.dart';
import 'package:sac_app/domain/models/smoke_test_record.dart';
import 'package:sac_app/domain/services/archive_service.dart';
import 'package:sac_app/domain/utils/path_masking.dart';
import 'package:sac_app/domain/utils/release_approval_policy.dart';

void main() {
  late Directory tempDir;
  late SacContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sac_sprint12_test_');
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
      name: 'Sprint12 WS',
      rootPath: p.join(tempDir.path, 'SAC S12'),
    );
    await container.bindWorkspace(workspace);
  }

  Future<void> recordVerificationSet({int testCount = 175}) async {
    final svc = container.verificationPassRecordService;
    const sprintCommit = '2e2e4da';
    await svc.recordPass(
      checkType: 'analyze',
      source: 'auto',
      verifiedHeadCommit: '2e2e4da',
      verifiedSprintCommit: sprintCommit,
    );
    await svc.recordPass(
      checkType: 'test',
      source: 'auto',
      testCount: testCount,
      verifiedHeadCommit: '2e2e4da',
      verifiedSprintCommit: sprintCommit,
    );
    await svc.recordPass(
      checkType: 'sidecar_build',
      source: 'auto',
      verifiedHeadCommit: '2e2e4da',
      verifiedSprintCommit: sprintCommit,
    );
  }

  Future<void> exportAllReleaseDocs() async {
    await container.releaseFinalizationExportService.exportReleaseNotes();
    await container.releaseFinalizationExportService.exportKnownIssues();
    await container.releaseFinalizationExportService.exportTagReadinessChecklist();
  }

  Future<void> passSmoke(String platform) async {
    await container.smokeApprovalService.updateSmokeApproval(
      platform: platform,
      status: SmokeTestStatus.passed,
      notes: 'Sprint12 PASS',
    );
  }

  test('migration v10 creates Sprint 12 tables', () async {
    await bindWorkspace();
    expect(await container.databaseService.getSchemaVersion(), kSacSchemaVersion);
    final db = container.databaseService.requireDatabase();
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final names = tables.map((r) => r['name'] as String).toSet();
    expect(names.contains('rc_build_artifacts'), isTrue);
    expect(names.contains('release_approval_records'), isTrue);
    expect(names.contains('rc_tag_readiness_checks'), isTrue);
  });

  test('RC build artifact record creates masked path entry', () async {
    await bindWorkspace();
    final artifact = await container.rcBuildArtifactService.recordBuildArtifact(
      platform: 'Windows',
      buildType: RcBuildType.rc,
      artifactPath: r'C:\Users\kuroi\build\app-release.apk',
      commitHash: '5e02b31',
      status: RcBuildArtifactStatus.pass,
      notes: 'rc candidate',
    );
    expect(artifact.artifactPathMasked, isNot(contains('kuroi')));
    expect(artifact.artifactPathMasked, contains('***'));
    final listed = await container.rcBuildArtifactService.listBuildArtifacts();
    expect(listed.length, 1);
  });

  test('artifact path masking hides user home segments', () {
    final masked = maskArtifactPath('/Users/alice/Projects/sac/build/app.zip');
    expect(masked.contains('alice'), isFalse);
    expect(masked, contains('***'));
  });

  test('smoke pending keeps approval waiting not ready_for_approval', () async {
    await bindWorkspace();
    await recordVerificationSet();
    await exportAllReleaseDocs();
    final approval = await container.releaseApprovalService.evaluateAndPersist();
    expect(approval.status, ReleaseApprovalStatus.waitingSmoke);
    expect(approval.statusLabel, contains('smoke'));
  });

  test('both smoke pass with verification yields ready_for_approval', () async {
    await bindWorkspace();
    await recordVerificationSet();
    await exportAllReleaseDocs();
    await passSmoke('macOS');
    await passSmoke('Windows');
    final approval = await container.releaseApprovalService.evaluateAndPersist();
    expect(approval.status, ReleaseApprovalStatus.readyForApproval);
    final readiness = await container.releaseReadinessService.evaluate();
    expect(readiness.rcFinalizationStatus, RcFinalizationStatus.ready);
    expect(readiness.isReadyForRc, isTrue);
  });

  test('failed smoke yields blocked approval', () async {
    await bindWorkspace();
    await recordVerificationSet();
    await passSmoke('macOS');
    await container.smokeApprovalService.updateSmokeApproval(
      platform: 'Windows',
      status: SmokeTestStatus.failed,
      notes: 'fail',
    );
    final approval = await container.releaseApprovalService.evaluateAndPersist();
    expect(approval.status, ReleaseApprovalStatus.blocked);
  });

  test('draft to waiting_smoke transition on verification only', () async {
    await bindWorkspace();
    var approval = await container.releaseApprovalService.evaluateAndPersist();
    expect(approval.status, ReleaseApprovalStatus.draft);
    await recordVerificationSet();
    approval = await container.releaseApprovalService.evaluateAndPersist();
    expect(approval.status, ReleaseApprovalStatus.waitingSmoke);
  });

  test('approval decision records approved status', () async {
    await bindWorkspace();
    await recordVerificationSet();
    await exportAllReleaseDocs();
    await passSmoke('macOS');
    await passSmoke('Windows');
    final approved = await container.releaseApprovalService.recordDecision(
      decision: ReleaseApprovalStatus.approved,
      notes: '소장님 승인 대기',
    );
    expect(approved.status, ReleaseApprovalStatus.approved);
    expect(approved.statusLabel, contains('승인'));
  });

  test('rejected decision records rejected status', () async {
    await bindWorkspace();
    final rejected = await container.releaseApprovalService.recordDecision(
      decision: ReleaseApprovalStatus.rejected,
      notes: '재검토',
    );
    expect(rejected.status, ReleaseApprovalStatus.rejected);
    final latest = await container.releaseApprovalService.getLatestSummary();
    expect(latest?.status, ReleaseApprovalStatus.rejected);
  });

  test('tag readiness checklist run persists checks', () async {
    await bindWorkspace();
    await recordVerificationSet();
    final summary = await container.rcTagReadinessService.runRcTagReadinessChecks();
    expect(summary.items, isNotEmpty);
    expect(summary.items.any((i) => i.checkLabel.contains('Git tag')), isTrue);
    final latest = await container.rcTagReadinessService.getLatestSummary();
    expect(latest?.runId, summary.runId);
  });

  test('tag readiness states no auto git tag creation', () async {
    await bindWorkspace();
    final summary = await container.rcTagReadinessService.runRcTagReadinessChecks();
    final tagItem = summary.items.firstWhere((i) => i.checkLabel.contains('Git tag'));
    expect(tagItem.passed, isTrue);
    expect(tagItem.detail, contains('manual'));
  });

  test('final release bundle export writes markdown file', () async {
    await bindWorkspace();
    await recordVerificationSet();
    final result = await container.finalReleaseBundleExportService.exportFinalReleaseBundle();
    expect(result.relativePath, contains('sac_v0.1_rc_bundle'));
    expect(File(result.absolutePath).existsSync(), isTrue);
    expect(await container.finalReleaseBundleExportService.hasFinalBundleExport(), isTrue);
  });

  test('final release bundle excludes sensitive document body', () async {
    await bindWorkspace();
    await container.archiveService.createDocument(
      const CreateDocumentInput(
        title: 'SecretDoc',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: 'TOP_SECRET_PERSONAL_BODY_99999',
      ),
    );
    await recordVerificationSet();
    final result = await container.finalReleaseBundleExportService.exportFinalReleaseBundle();
    expect(result.markdown.contains('TOP_SECRET_PERSONAL_BODY_99999'), isFalse);
  });

  test('final release bundle excludes secret token api key patterns', () async {
    await bindWorkspace();
    await recordVerificationSet();
    final result = await container.finalReleaseBundleExportService.exportFinalReleaseBundle();
    expect(exportContainsSensitivePatterns(result.markdown), isFalse);
  });

  test('dashboard includes rc final status summary', () async {
    await bindWorkspace();
    await recordVerificationSet();
    final dashboard = await container.dashboardService.getDashboardSummary();
    expect(dashboard.rcFinalStatus.approvalLabel, isNotEmpty);
    expect(dashboard.rcFinalStatus.rcCommitHash, isNotEmpty);
    expect(dashboard.rcFinalStatus.approvalStatus, isNot(ReleaseApprovalStatus.approved));
  });

  test('release approval service exposes summary for settings', () async {
    await bindWorkspace();
    await recordVerificationSet();
    final summary = await container.releaseApprovalService.evaluateAndPersist();
    expect(summary.rcCommitHash, isNotEmpty);
    expect(releaseApprovalStatusLabel(summary.status), summary.statusLabel);
  });

  test('computeReleaseApprovalStatus blocked on integrity critical', () {
    final status = computeReleaseApprovalStatus(
      rcFinalizationStatus: RcFinalizationStatus.ready,
      verificationComplete: true,
      releaseNotesExported: true,
      knownIssuesExported: true,
      tagReadinessExported: true,
      macSmokeStatus: SmokeTestStatus.passed,
      winSmokeStatus: SmokeTestStatus.passed,
      integrityCritical: true,
    );
    expect(status, ReleaseApprovalStatus.blocked);
  });

  test('report manifest includes Sprint 12 and RC verification baseline', () {
    expect(kSprintReportCommitManifest['Sprint 12'], '2e2e4da');
    expect(kRcVerificationSprintCommit, '2e2e4da');
    expect(kRcVerificationSprintLabel, 'Sprint 12');
  });

  test('Sprint 11 rc finalization regression still evaluates verification items', () async {
    await bindWorkspace();
    final summary = await container.releaseReadinessService.evaluate();
    expect(summary.items.any((i) => i.category == 'verification'), isTrue);
    expect(summary.rcFinalizationStatus, isNot(RcFinalizationStatus.ready));
  });
}
