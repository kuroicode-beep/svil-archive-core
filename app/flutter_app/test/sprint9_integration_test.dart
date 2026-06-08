// sprint9_integration_test.dart — Integrity / Recovery / Smoke 통합 테스트

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/db/migrations.dart';
import 'package:sac_app/data/services/report_consistency_service_impl.dart';
import 'package:sac_app/domain/models/execution_recovery.dart';
import 'package:sac_app/domain/models/integrity_scan.dart';
import 'package:sac_app/domain/models/smoke_test_record.dart';
import 'package:sac_app/domain/models/ticket_execution.dart';
import 'package:sac_app/domain/models/work_queue.dart';
import 'package:sac_app/domain/services/archive_service.dart';

void main() {
  late Directory tempDir;
  late SacContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sac_sprint9_test_');
    container = await SacContainer.create(registryDirectory: tempDir.path);
  });

  tearDown(() async {
    await container.databaseService.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> bindWorkspace() async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Sprint9 WS',
      rootPath: p.join(tempDir.path, 'SAC S9'),
    );
    await container.bindWorkspace(workspace);
  }

  Future<void> enableTool(String name) async {
    await container.mcpToolRegistryService.setToolEnabled(name, true);
  }

  Future<WorkQueueTicket> createApprovedUserTicket(
    CreateWorkQueueTicketInput input,
  ) async {
    final ticket = await container.workQueueService.createTicket(input);
    await container.workQueueService.approveTicket(ticket.id);
    return (await container.workQueueService.findTicketById(ticket.id))!;
  }

  Future<void> writeOrphanFile(String relativePath, {String content = '# orphan'}) async {
    final root = container.activeWorkspace!.rootPath;
    final file = File(p.join(root, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  test('migration v7 creates integrity and smoke tables', () async {
    await bindWorkspace();
    expect(await container.databaseService.getSchemaVersion(), kSacSchemaVersion);
    final db = container.databaseService.requireDatabase();
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final names = tables.map((r) => r['name'] as String).toSet();
    expect(names.contains('integrity_scan_runs'), isTrue);
    expect(names.contains('integrity_scan_items'), isTrue);
    expect(names.contains('smoke_test_records'), isTrue);
  });

  test('migration v7 extends work_queue with recovery columns', () async {
    await bindWorkspace();
    final db = container.databaseService.requireDatabase();
    final columns = await db.rawQuery('PRAGMA table_info(work_queue_tickets)');
    final colNames = columns.map((c) => c['name'] as String).toSet();
    expect(colNames.contains('source_ticket_id'), isTrue);
    expect(colNames.contains('recovery_kind'), isTrue);
  });

  test('file inventory lists markdown under documents', () async {
    await bindWorkspace();
    await writeOrphanFile('documents/Dev/inventory_s9.md');
    final paths = await container.fileInventoryService.listWorkspaceMarkdownPaths();
    expect(paths, contains('documents/Dev/inventory_s9.md'));
  });

  test('integrity scan detects orphan markdown', () async {
    await bindWorkspace();
    await writeOrphanFile('documents/Dev/orphan_scan_s9.md');
    final run = await container.workspaceIntegrityService.runScan();
    expect(run.orphanCount, greaterThanOrEqualTo(1));
    final summary = await container.workspaceIntegrityService.getLatestSummary();
    expect(summary.openOrphanCount, greaterThanOrEqualTo(1));
    final items = await container.workspaceIntegrityService.listOpenItems();
    expect(
      items.any((i) => i.itemType == IntegrityItemType.orphanMarkdown),
      isTrue,
    );
  });

  test('integrity scan detects stale db row', () async {
    await bindWorkspace();
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'Stale S9',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# stale',
      ),
    );
    final root = container.activeWorkspace!.rootPath;
    final file = File(p.join(root, doc.metadata.path));
    expect(await file.exists(), isTrue);
    await file.delete();
    final run = await container.workspaceIntegrityService.runScan();
    expect(run.staleDbCount, greaterThanOrEqualTo(1));
    final summary = await container.workspaceIntegrityService.getLatestSummary();
    expect(summary.openStaleDbCount, greaterThanOrEqualTo(1));
  });

  test('scan does not auto-delete orphan files', () async {
    await bindWorkspace();
    const orphanPath = 'documents/Dev/no_auto_delete_s9.md';
    await writeOrphanFile(orphanPath);
    await container.workspaceIntegrityService.runScan();
    final root = container.activeWorkspace!.rootPath;
    expect(await File(p.join(root, orphanPath)).exists(), isTrue);
    final db = container.databaseService.requireDatabase();
    final docRows = await db.query(
      'documents',
      where: 'relative_path = ?',
      whereArgs: [orphanPath],
    );
    expect(docRows, isEmpty);
  });

  test('orphan overwrite blocked on create_document execution', () async {
    await bindWorkspace();
    await enableTool('create_document');
    const orphanPath = 'documents/Dev/Orphan_Guard.md';
    await writeOrphanFile(orphanPath, content: '# existing orphan');
    final ticket = await createApprovedUserTicket(
      const CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: orphanPath,
        permissionLevel: PermissionLevel.write,
        payloadJson: '{"title":"Orphan_Guard","relativeDir":"documents/Dev","type":"Dev"}',
      ),
    );
    final result = await container.queueExecutionService.executeApprovedTicket(ticket.id);
    expect(result.status, ExecutionResultStatus.failed);
    expect(result.errorCode, 'orphan_file_exists');
    final updated = (await container.workQueueService.findTicketById(ticket.id))!;
    expect(updated.status, WorkQueueTicketStatus.failed);
  });

  test('recovery assessment eligible for failed ticket', () async {
    await bindWorkspace();
    await enableTool('create_document');
    const orphanPath = 'documents/Dev/Recovery_Failed.md';
    await writeOrphanFile(orphanPath);
    final ticket = await createApprovedUserTicket(
      const CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: orphanPath,
        permissionLevel: PermissionLevel.write,
        payloadJson: '{"title":"Recovery_Failed","relativeDir":"documents/Dev","type":"Dev"}',
      ),
    );
    await container.queueExecutionService.executeApprovedTicket(ticket.id);
    final assessment = await container.executionRecoveryService.assessTicket(ticket.id);
    expect(assessment.eligibility, RecoveryEligibility.eligible);
    expect(assessment.dryRunAvailable, isTrue);
  });

  test('recovery assessment not eligible for completed ticket', () async {
    await bindWorkspace();
    await enableTool('create_document');
    final ticket = await createApprovedUserTicket(
      const CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: 'documents/Dev/recovery_done.md',
        permissionLevel: PermissionLevel.write,
        payloadJson: '{"title":"Recovery Done","relativeDir":"documents/Dev"}',
      ),
    );
    await container.queueExecutionService.executeApprovedTicket(ticket.id);
    final assessment = await container.executionRecoveryService.assessTicket(ticket.id);
    expect(assessment.eligibility, RecoveryEligibility.notEligible);
  });

  test('create recovery ticket from failed source', () async {
    await bindWorkspace();
    await enableTool('create_document');
    const orphanPath = 'documents/Dev/Recovery_Create.md';
    await writeOrphanFile(orphanPath);
    final source = await createApprovedUserTicket(
      const CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: orphanPath,
        permissionLevel: PermissionLevel.write,
        payloadJson: '{"title":"Recovery_Create","relativeDir":"documents/Dev","type":"Dev"}',
      ),
    );
    await container.queueExecutionService.executeApprovedTicket(source.id);
    final recovery = await container.executionRecoveryService.createRecoveryTicket(source.id);
    expect(recovery.isRecoveryTicket, isTrue);
    expect(recovery.sourceTicketId, source.id);
    expect(recovery.recoveryKind, 'execution_recovery');
    expect(recovery.status, WorkQueueTicketStatus.pending);
    expect(recovery.requestedAction, 'recovery_create_document');
  });

  test('source failed ticket is not re-executed by recovery flow', () async {
    await bindWorkspace();
    await enableTool('create_document');
    const orphanPath = 'documents/Dev/No_Reexec.md';
    await writeOrphanFile(orphanPath);
    final source = await createApprovedUserTicket(
      const CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: orphanPath,
        permissionLevel: PermissionLevel.write,
        payloadJson: '{"title":"No_Reexec","relativeDir":"documents/Dev","type":"Dev"}',
      ),
    );
    await container.queueExecutionService.executeApprovedTicket(source.id);
    final before = (await container.workQueueService.findTicketById(source.id))!;
    expect(before.status, WorkQueueTicketStatus.failed);
    await container.executionRecoveryService.createRecoveryTicket(source.id);
    final after = (await container.workQueueService.findTicketById(source.id))!;
    expect(after.status, WorkQueueTicketStatus.failed);
    expect(
      () => container.queueExecutionService.executeApprovedTicket(source.id),
      throwsA(isA<StateError>()),
    );
  });

  test('recovery preview does not store sensitive body', () async {
    await bindWorkspace();
    await enableTool('create_document');
    const sensitive = 'SECRET_RECOVERY_PREVIEW_888';
    const orphanPath = 'documents/Dev/Recovery_Preview.md';
    await writeOrphanFile(orphanPath, content: sensitive);
    final source = await createApprovedUserTicket(
      CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: orphanPath,
        permissionLevel: PermissionLevel.write,
        payloadJson: jsonEncode({
          'title': 'Recovery_Preview',
          'relativeDir': 'documents/Dev',
          'type': 'Dev',
          'initialContent': sensitive,
        }),
      ),
    );
    await container.queueExecutionService.executeApprovedTicket(source.id);
    await container.executionRecoveryService.createRecoveryPreview(source.id);
    final db = container.databaseService.requireDatabase();
    final rows = await db.query('ticket_dry_run_previews');
    for (final row in rows) {
      final summary = row['summary'] as String? ?? '';
      expect(summary.contains('SECRET_RECOVERY_PREVIEW'), isFalse);
    }
  });

  test('report consistency default is consistent', () async {
    await bindWorkspace();
    final report = await container.reportConsistencyService.checkReports();
    expect(report.isConsistent, isTrue);
    expect(report.mismatches, isEmpty);
  });

  test('report consistency reads local docs reports and handoff', () async {
    final docsRoot = p.normalize(p.join(Directory.current.path, '..', '..', 'docs'));
    final docsContainer = await SacContainer.create(
      registryDirectory: tempDir.path,
      reportDocsRoot: docsRoot,
    );
    final workspace = await docsContainer.workspaceService.createWorkspace(
      name: 'Sprint9 Docs WS',
      rootPath: p.join(tempDir.path, 'SAC S9 Docs'),
    );
    await docsContainer.bindWorkspace(workspace);
    final report = await docsContainer.reportConsistencyService.checkReports();
    expect(report.isConsistent, isTrue);
    expect(report.mismatches, isEmpty);
    await docsContainer.databaseService.close();
  });

  test('report consistency detects wrong commit in local docs', () async {
    final docsRoot = Directory(p.join(tempDir.path, 'fake_docs'));
    await Directory(p.join(docsRoot.path, 'handoff')).create(recursive: true);
    await File(p.join(docsRoot.path, 'handoff', 'Codex_Verification_Request_Sprint_08.md'))
        .writeAsString('> **Sprint 08 구현 커밋**: `deadbeef`\n');
    final docsContainer = await SacContainer.create(
      registryDirectory: p.join(tempDir.path, 'registry2'),
      reportDocsRoot: docsRoot.path,
    );
    final workspace = await docsContainer.workspaceService.createWorkspace(
      name: 'Sprint9 Bad Docs',
      rootPath: p.join(tempDir.path, 'SAC S9 Bad'),
    );
    await docsContainer.bindWorkspace(workspace);
    final report = await docsContainer.reportConsistencyService.checkReports();
    expect(report.isConsistent, isFalse);
    expect(
      report.mismatches.any((m) => m.sprintLabel == 'Sprint 08'),
      isTrue,
    );
    await docsContainer.databaseService.close();
  });

  test('report mismatch detected when stored hash differs', () async {
    await bindWorkspace();
    final db = container.databaseService.requireDatabase();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('app_settings', {
      'key': 'report_commit_sprint_08',
      'value': 'deadbeef',
      'updated_at': now,
    });
    final report = await container.reportConsistencyService.checkReports();
    expect(report.isConsistent, isFalse);
    final sprint08Mismatches =
        report.mismatches.where((m) => m.sprintLabel == 'Sprint 08').toList();
    expect(sprint08Mismatches.length, 1);
    expect(sprint08Mismatches.first.sprintLabel, 'Sprint 08');
    expect(report.mismatches.first.expectedCommit, kSprintReportCommitManifest['Sprint 08']);
  });

  test('integrity scan includes report mismatch items', () async {
    await bindWorkspace();
    final db = container.databaseService.requireDatabase();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('app_settings', {
      'key': 'report_commit_sprint_07',
      'value': 'badhash1',
      'updated_at': now,
    });
    final run = await container.workspaceIntegrityService.runScan();
    expect(run.warningCount, greaterThanOrEqualTo(1));
    final items = await container.workspaceIntegrityService.listOpenItems();
    expect(
      items.any((i) => i.itemType == IntegrityItemType.reportMismatch),
      isTrue,
    );
  });

  test('smoke test record create and latest for macOS', () async {
    await bindWorkspace();
    final created = await container.smokeTestRecordService.createRecord(
      platform: 'macOS',
      checklistName: 'SAC macOS Smoke',
      status: SmokeTestStatus.pending,
      notes: 'Sprint 09 test — no sensitive body',
    );
    expect(created.platform, 'macOS');
    final latest = await container.smokeTestRecordService.getLatestForPlatform('macOS');
    expect(latest, isNotNull);
    expect(latest!.id, created.id);
    expect(latest.notes?.contains('SECRET'), isFalse);
  });

  test('dashboard reflects integrity summary', () async {
    await bindWorkspace();
    await writeOrphanFile('documents/Dev/dash_integrity_s9.md');
    await container.workspaceIntegrityService.runScan();
    await container.smokeTestRecordService.createRecord(
      platform: 'macOS',
      checklistName: 'SAC macOS Smoke',
      status: SmokeTestStatus.pending,
    );
    final summary = await container.dashboardService.getDashboardSummary();
    expect(summary.integritySummary.openOrphanCount, greaterThanOrEqualTo(1));
    expect(summary.reportConsistent, isTrue);
    expect(summary.macSmokeStatus, SmokeTestStatus.pending);
  });

  test('privacy reflects integrity summary', () async {
    await bindWorkspace();
    await writeOrphanFile('documents/Dev/privacy_integrity_s9.md');
    await container.workspaceIntegrityService.runScan();
    final privacy = await container.privacyService.getPrivacySummary();
    expect(privacy.integritySummary.openOrphanCount, greaterThanOrEqualTo(1));
    expect(privacy.reportConsistent, isTrue);
  });

  test('recovery assessment eligible for blocked ticket', () async {
    await bindWorkspace();
    await enableTool('update_document');
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'Blocked Recovery',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# blocked',
      ),
    );
    final ticket = await createApprovedUserTicket(
      CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'update_document',
        targetType: 'document',
        targetId: doc.metadata.id,
        targetPath: doc.metadata.path,
        permissionLevel: PermissionLevel.write,
        payloadJson: jsonEncode({'content': '# no revision'}),
      ),
    );
    await container.queueExecutionService.executeApprovedTicket(ticket.id);
    final updated = (await container.workQueueService.findTicketById(ticket.id))!;
    expect(updated.status, WorkQueueTicketStatus.blocked);
    final assessment = await container.executionRecoveryService.assessTicket(ticket.id);
    expect(assessment.eligibility, RecoveryEligibility.eligible);
  });

  test('Sprint 08 approved-only execution regression', () async {
    await bindWorkspace();
    await enableTool('create_document');
    final ticket = await container.workQueueService.createTicket(
      const CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: 'documents/Dev/s9-regression-pending.md',
        permissionLevel: PermissionLevel.write,
        payloadJson: '{"title":"S9 Pending","relativeDir":"documents/Dev"}',
      ),
    );
    expect(
      () => container.queueExecutionService.executeApprovedTicket(ticket.id),
      throwsA(isA<StateError>()),
    );
  });

  test('Sprint 08 baseRevision required regression', () async {
    await bindWorkspace();
    await enableTool('update_document');
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'S9 Base Rev',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# s9 base',
      ),
    );
    final ticket = await createApprovedUserTicket(
      CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'update_document',
        targetType: 'document',
        targetId: doc.metadata.id,
        targetPath: doc.metadata.path,
        permissionLevel: PermissionLevel.write,
        payloadJson: jsonEncode({'content': '# blocked s9'}),
      ),
    );
    final result = await container.queueExecutionService.executeApprovedTicket(ticket.id);
    expect(result.status, ExecutionResultStatus.blocked);
    expect((await container.workQueueService.findTicketById(ticket.id))!.status,
        WorkQueueTicketStatus.blocked);
  });

  test('Sprint 07 MCP enqueue without direct execution regression', () async {
    await bindWorkspace();
    await enableTool('update_document');
    final writeToken = await container.permissionTokenService.issueToken(
      tokenType: PermissionLevel.write,
      actor: 'mcp-agent',
      scope: 'workspace',
    );
    final ticket = await container.mcpBridgeStatusService.enqueueToolRequest(
      McpToolRequest(
        toolName: 'update_document',
        actor: 'mcp-agent',
        targetPath: 'documents/Dev/sample.md',
        permissionTokenId: writeToken.id,
      ),
    );
    expect(ticket.status, WorkQueueTicketStatus.pending);
    expect(
      () => container.queueExecutionService.executeApprovedTicket(ticket.id),
      throwsA(isA<StateError>()),
    );
  });

  test('integrity scan notes do not store file body content', () async {
    await bindWorkspace();
    const sensitive = 'SECRET_SCAN_BODY_555';
    await writeOrphanFile('documents/Dev/scan_body_s9.md', content: sensitive);
    await container.workspaceIntegrityService.runScan();
    final db = container.databaseService.requireDatabase();
    final rows = await db.query('integrity_scan_items');
    for (final row in rows) {
      final reason = row['reason'] as String? ?? '';
      expect(reason.contains('SECRET_SCAN_BODY'), isFalse);
    }
  });
}
