// sprint_v020_sprint01_integration_test.dart — v0.2.0 Sprint 01 Relay Foundation

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/db/migrations.dart';
import 'package:sac_app/data/platform/path_adapter.dart';
import 'package:sac_app/data/platform/platform_path_adapter.dart';
import 'package:sac_app/data/relay/relay_idempotency_service.dart';
import 'package:sac_app/data/relay/relay_journal_events.dart';
import 'package:sac_app/data/services/git_sync_service_impl.dart';
import 'package:sac_app/domain/models/import_queue_item.dart';
import 'package:sac_app/domain/models/relay_queue_item.dart';
import 'package:sac_app/domain/models/relay_sensitivity.dart';

void main() {
  late Directory tempDir;
  late SacContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sac_v020_s01_');
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
      name: 'v020 Sprint01',
      rootPath: p.join(tempDir.path, 'SAC DOCS'),
    );
    await container.bindWorkspace(workspace);
  }

  test('migration v12 creates relay tables and journal columns', () async {
    await bindWorkspace();
    final db = container.databaseService.requireDatabase();
    final version = await container.databaseService.getSchemaVersion();
    expect(version, kSacSchemaVersion);
    expect(version, 12);

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final names = tables.map((r) => r['name'] as String).toSet();
    expect(names.contains('relay_queue'), isTrue);
    expect(names.contains('relay_idempotency_keys'), isTrue);
    expect(names.contains('relay_capability_tokens'), isTrue);
    expect(names.contains('relay_result_reviews'), isTrue);
    expect(names.contains('public_lumi_capsules'), isTrue);

    final journalInfo = await db.rawQuery('PRAGMA table_info(sync_journal)');
    final journalCols = journalInfo.map((r) => r['name'] as String).toSet();
    expect(journalCols.contains('idempotency_key'), isTrue);
    expect(journalCols.contains('payload_json'), isTrue);
  });

  test('import_queue and relay_queue statuses stay separate', () async {
    await bindWorkspace();
    final importItem = await container.importQueueService.enqueueDetected(
      sourceAbsolutePath: p.normalize('C:/Downloads/ai_sync_sac_note_test.md'),
      originalFileName: 'ai_sync_sac_note_test.md',
      matchedPrefix: 'ai_sync_',
      targetFileName: 'sac_note_test.md',
      sourceAi: 'lumi',
      fileSize: 42,
    );
    expect(importItem, isNotNull);
    expect(importItem!.status, ImportQueueStatus.detected);

    final relayItem = await container.relayQueueService.enqueueTask(
      sourceImportQueueId: importItem.id,
      targetAgent: 'somi',
      eventType: 'task_request',
    );
    expect(relayItem.status, RelayQueueStatus.pending);

    await container.importQueueService.updateStatus(
      importItem.id,
      ImportQueueStatus.imported,
      importedDocumentId: 'doc-1',
    );
    final relayAfter = await container.relayQueueService.findById(relayItem.id);
    expect(relayAfter!.status, RelayQueueStatus.pending);
  });

  test('relay journal records task created event', () async {
    await bindWorkspace();
    await container.relayQueueService.enqueueTask(
      targetAgent: 'somi',
      eventType: 'task_request',
    );
    final db = container.databaseService.requireDatabase();
    final rows = await db.query(
      'sync_journal',
      where: 'action = ?',
      whereArgs: [RelayJournalEvents.relayTaskCreated],
    );
    expect(rows, isNotEmpty);
  });

  test('idempotency prevents duplicate relay journal events', () async {
    await bindWorkspace();
    final key = RelayIdempotencyService.buildKey(
      contentHash: 'abc',
      normalizedSourcePath: 'C:/Downloads/file.md',
      eventType: 'watcher_detect',
    );
    final service = RelayIdempotencyService(
      databaseService: container.databaseService,
    );
    expect(await service.registerIfAbsent(idempotencyKey: key, eventType: 'watcher_detect'), isTrue);
    expect(await service.registerIfAbsent(idempotencyKey: key, eventType: 'watcher_detect'), isFalse);
  });

  test('medium_unknown with sensitive pattern blocks public export', () async {
    await bindWorkspace();
    final assessment = container.relaySensitivityService.assessAndRedact(
      content: 'contact: user@example.com api_key=secret123',
    );
    expect(assessment.sensitivityLabel, SensitivityLabel.mediumUnknown);
    expect(assessment.exportAllowed, isFalse);
    expect(assessment.redactionStatus, RedactionStatus.blocked);
  });

  test('regex redaction applies to preview text', () async {
    await bindWorkspace();
    final assessment = container.relaySensitivityService.assessAndRedact(
      explicitLabel: 'low',
      content: 'email test@mail.com only',
    );
    final redacted = container.relaySensitivityService.applyRedaction(
      'email test@mail.com only',
      assessment,
    );
    expect(redacted.contains('test@mail.com'), isFalse);
    expect(redacted.contains('[REDACTED]'), isTrue);
  });

  test('public_lumi paths are excluded from git commit safety', () {
    expect(isExcludedFromCommit('SAC_EXPORTS/public_lumi/status.html'), isTrue);
    expect(isExcludedFromCommit('documents/Dev/note.md'), isFalse);
    final root = resolvePublicLumiExportRoot(r'C:\Users\test\SAC DOCS');
    expect(root.toLowerCase().contains('sac_exports'), isTrue);
  });

  test('capability token rejects missing target_document_id when scoped', () async {
    await bindWorkspace();
    const taskId = 'relay_target_doc_missing';
    final token = await container.relayCapabilityTokenService.issueForTask(
      taskId: taskId,
      allowedAction: 'draft_update',
      allowedTarget: 'doc-scoped-1',
      targetDocumentId: 'doc-scoped-1',
    );
    final valid = await container.relayCapabilityTokenService.validate(
      taskId: taskId,
      plainToken: token,
      resultType: 'draft_update',
    );
    expect(valid, isFalse);

    final outcome = await container.relayResultIntakeService.intakeResult(
      frontmatter: {
        'sac_event': 'relay_result',
        'task_id': taskId,
        'capability_token': token,
        'result_type': 'draft_update',
      },
      sourcePath: 'C:/Downloads/missing_target.md',
    );
    expect(outcome.accepted, isFalse);
    expect(outcome.reason, 'capability_token_invalid');
  });

  test('capability token rejects wrong target_document_id', () async {
    await bindWorkspace();
    const taskId = 'relay_target_doc_wrong';
    final token = await container.relayCapabilityTokenService.issueForTask(
      taskId: taskId,
      allowedAction: 'draft_update',
      allowedTarget: 'doc-scoped-2',
      targetDocumentId: 'doc-scoped-2',
    );
    expect(
      await container.relayCapabilityTokenService.validate(
        taskId: taskId,
        plainToken: token,
        resultType: 'draft_update',
        targetDocumentId: 'doc-other',
      ),
      isFalse,
    );
  });

  test('capability token accepts matching target_document_id', () async {
    await bindWorkspace();
    const taskId = 'relay_target_doc_ok';
    final token = await container.relayCapabilityTokenService.issueForTask(
      taskId: taskId,
      allowedAction: 'draft_update',
      allowedTarget: 'doc-scoped-3',
      targetDocumentId: 'doc-scoped-3',
    );
    expect(
      await container.relayCapabilityTokenService.validate(
        taskId: taskId,
        plainToken: token,
        resultType: 'draft_update',
        targetDocumentId: 'doc-scoped-3',
      ),
      isTrue,
    );

    final outcome = await container.relayResultIntakeService.intakeResult(
      frontmatter: {
        'sac_event': 'relay_result',
        'task_id': taskId,
        'capability_token': token,
        'result_type': 'draft_update',
        'target_document_id': 'doc-scoped-3',
      },
      sourcePath: 'C:/Downloads/ok_target.md',
    );
    expect(outcome.accepted, isTrue);
  });

  test('capability token rejects missing and wrong target_path', () async {
    await bindWorkspace();
    const taskId = 'relay_target_path_scope';
    const expectedPath = r'C:\SAC DOCS\documents\Dev\note.md';
    final token = await container.relayCapabilityTokenService.issueForTask(
      taskId: taskId,
      allowedAction: 'draft_update',
      allowedTarget: expectedPath,
      targetPath: expectedPath,
    );

    expect(
      await container.relayCapabilityTokenService.validate(
        taskId: taskId,
        plainToken: token,
        resultType: 'draft_update',
      ),
      isFalse,
    );
    expect(
      await container.relayCapabilityTokenService.validate(
        taskId: taskId,
        plainToken: token,
        resultType: 'draft_update',
        targetPath: r'C:/SAC DOCS/documents/Dev/other.md',
      ),
      isFalse,
    );
    expect(
      await container.relayCapabilityTokenService.validate(
        taskId: taskId,
        plainToken: token,
        resultType: 'draft_update',
        targetPath: r'C:/SAC DOCS/documents/Dev/note.md',
      ),
      isTrue,
    );
  });

  test('capability token failure isolates result to review inbox', () async {
    await bindWorkspace();
    final outcome = await container.relayResultIntakeService.intakeResult(
      frontmatter: {
        'sac_event': 'relay_result',
        'task_id': 'relay_test_001',
        'capability_token': 'invalid',
        'result_type': 'draft_update',
      },
      sourcePath: 'C:/Downloads/result.md',
    );
    expect(outcome.accepted, isFalse);
    expect(outcome.reviewId, isNotNull);
    final pending = await container.relayResultIntakeService.listPendingReviews();
    expect(pending.length, greaterThanOrEqualTo(1));
  });

  test('manual rescue approval records journal event', () async {
    await bindWorkspace();
    final outcome = await container.relayResultIntakeService.intakeResult(
      frontmatter: {
        'sac_event': 'relay_result',
        'task_id': 'relay_test_002',
        'capability_token': 'bad',
        'result_type': 'draft_update',
      },
      sourcePath: 'C:/Downloads/result2.md',
    );
    await container.relayResultIntakeService.approveManualRescue(
      outcome.reviewId!,
      actor: 'user',
    );
    final db = container.databaseService.requireDatabase();
    final rows = await db.query(
      'sync_journal',
      where: 'action = ?',
      whereArgs: [RelayJournalEvents.manualRescueApproved],
    );
    expect(rows, isNotEmpty);
  });

  test('platform path adapter ignores temp downloads and normalizes paths', () {
    expect(isTemporaryDownloadFile(r'C:\Downloads\file.crdownload'), isTrue);
    expect(isTemporaryDownloadFile(r'C:\Downloads\file.tmp'), isTrue);
    expect(isMarkdownDownloadCandidate(r'C:\Downloads\note.md'), isTrue);
    final normalized = normalizeSourcePathForIdempotency(
      r'C:\Downloads\ai_sync_note(1).md',
    );
    expect(normalized.endsWith('ai_sync_note.md'), isTrue);
    expect(normalizePlatformPath(r'C:\Users\test\Downloads'), isNotEmpty);
  });

  test('public_lumi GC deletes expired capsule but not workspace documents', () async {
    await bindWorkspace();
    final workspace = container.activeWorkspace!;
    final docDir = Directory(p.join(workspace.rootPath, 'documents', 'Dev'));
    await docDir.create(recursive: true);
    final docFile = File(p.join(docDir.path, 'keep_me.md'));
    await docFile.writeAsString('# keep');

    final exportRoot = resolvePublicLumiExportRoot(workspace.rootPath);
    const capsuleId = 'capsule-gc-test';
    final capsuleDir = Directory(publicLumiCapsuleDirectory(exportRoot, capsuleId));
    await capsuleDir.create(recursive: true);
    await File(p.join(capsuleDir.path, 'manifest.json')).writeAsString('{}');

    await container.publicLumiGcService.registerCapsule(
      workspaceRoot: workspace.rootPath,
      capsuleId: capsuleId,
      expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      bodyPolicy: 'summary_only',
      sensitivityPolicy: 'low',
      exportMode: 'preview',
    );

    final deleted = await container.publicLumiGcService.runGc(
      workspaceRoot: workspace.rootPath,
    );
    expect(deleted, 1);
    expect(await capsuleDir.exists(), isFalse);
    expect(await docFile.exists(), isTrue);
  });
}
