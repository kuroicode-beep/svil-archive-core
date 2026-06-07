// sprint8_integration_test.dart — Queue Execution / Safe Apply 통합 테스트

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/db/migrations.dart';
import 'package:sac_app/domain/models/personal_archive.dart';
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
    tempDir = await Directory.systemTemp.createTemp('sac_sprint8_test_');
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
      name: 'Sprint8 WS',
      rootPath: p.join(tempDir.path, 'SAC S8'),
    );
    await container.bindWorkspace(workspace);
  }

  Future<String> issueToken(PermissionLevel type) async {
    final token = await container.permissionTokenService.issueToken(
      tokenType: type,
      actor: 'mcp-agent',
      scope: 'workspace',
    );
    return token.id;
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

  test('migration v6 creates execution and dry-run tables', () async {
    await bindWorkspace();
    expect(await container.databaseService.getSchemaVersion(), kSacSchemaVersion);
    final db = container.databaseService.requireDatabase();
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final names = tables.map((r) => r['name'] as String).toSet();
    expect(names.contains('ticket_execution_logs'), isTrue);
    expect(names.contains('ticket_dry_run_previews'), isTrue);
    final columns = await db.rawQuery('PRAGMA table_info(work_queue_tickets)');
    final colNames = columns.map((c) => c['name'] as String).toSet();
    expect(colNames.contains('base_revision'), isTrue);
    expect(colNames.contains('permission_token_id'), isTrue);
    expect(colNames.contains('payload_json'), isTrue);
  });

  test('pending ticket cannot dry-run or execute', () async {
    await bindWorkspace();
    await enableTool('update_document');
    final writeToken = await issueToken(PermissionLevel.write);
    final ticket = await container.workQueueService.createTicket(
      CreateWorkQueueTicketInput(
        actor: 'mcp-agent',
        requestedAction: 'update_document',
        targetType: 'document',
        targetPath: 'documents/Dev/sample.md',
        permissionLevel: PermissionLevel.write,
        permissionTokenId: writeToken,
      ),
    );
    expect(
      () => container.queueExecutionService.createDryRunPreview(ticket.id),
      throwsA(isA<StateError>()),
    );
    expect(
      () => container.queueExecutionService.executeApprovedTicket(ticket.id),
      throwsA(isA<StateError>()),
    );
  });

  test('blocked ticket cannot execute', () async {
    await bindWorkspace();
    final writeToken = await issueToken(PermissionLevel.write);
    final ticket = await container.workQueueService.createTicket(
      CreateWorkQueueTicketInput(
        actor: 'mcp-agent',
        requestedAction: 'update_document',
        targetType: 'document',
        targetPath: '../../outside.md',
        permissionLevel: PermissionLevel.write,
        permissionTokenId: writeToken,
      ),
    );
    expect(ticket.status, WorkQueueTicketStatus.blocked);
    expect(
      () => container.queueExecutionService.executeApprovedTicket(ticket.id),
      throwsA(isA<StateError>()),
    );
  });

  test('conflict ticket cannot execute', () async {
    await bindWorkspace();
    await enableTool('update_document');
    final writeToken = await issueToken(PermissionLevel.write);
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'Conflict Exec',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# conflict',
      ),
    );
    final sync = await container.syncService.getSyncState(doc.metadata.id);
    final ticket = await container.workQueueService.createTicket(
      CreateWorkQueueTicketInput(
        actor: 'mcp-agent',
        requestedAction: 'update_document',
        targetType: 'document',
        targetId: doc.metadata.id,
        targetPath: doc.metadata.path,
        permissionLevel: PermissionLevel.write,
        permissionTokenId: writeToken,
        baseRevision: sync.revision - 1,
      ),
    );
    expect(ticket.status, WorkQueueTicketStatus.conflict);
    expect(
      () => container.queueExecutionService.executeApprovedTicket(ticket.id),
      throwsA(isA<StateError>()),
    );
  });

  test('approved create_document executes successfully', () async {
    await bindWorkspace();
    await enableTool('create_document');
    const sensitive = 'SECRET_CREATE_BODY_999';
    final ticket = await createApprovedUserTicket(
      CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: 'documents/Dev/exec-create.md',
        permissionLevel: PermissionLevel.write,
        payloadJson: jsonEncode({
          'title': 'Exec Create',
          'relativeDir': 'documents/Dev',
          'type': 'Dev',
          'initialContent': sensitive,
        }),
      ),
    );
    final result = await container.queueExecutionService.executeApprovedTicket(ticket.id);
    expect(result.status, ExecutionResultStatus.success);
    final updated = (await container.workQueueService.findTicketById(ticket.id))!;
    expect(updated.status, WorkQueueTicketStatus.completed);
    final docs = await container.archiveService.listDocuments();
    expect(docs.any((d) => d.title == 'Exec Create'), isTrue);
  });

  test('approved update_document without baseRevision is blocked', () async {
    await bindWorkspace();
    await enableTool('update_document');
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'No Base Rev',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# no base',
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
        payloadJson: jsonEncode({'content': '# should not apply'}),
      ),
    );
    expect(ticket.baseRevision, isNull);
    final result = await container.queueExecutionService.executeApprovedTicket(ticket.id);
    expect(result.status, ExecutionResultStatus.blocked);
    final updated = (await container.workQueueService.findTicketById(ticket.id))!;
    expect(updated.status, WorkQueueTicketStatus.blocked);
    final loaded = await archive.getDocumentWithContent(doc.metadata.id);
    expect(loaded?.content?.rawMarkdown, contains('no base'));
  });

  test('approved update_document executes successfully', () async {
    await bindWorkspace();
    await enableTool('update_document');
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'Before Update',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# before',
      ),
    );
    final sync = await container.syncService.getSyncState(doc.metadata.id);
    final ticket = await createApprovedUserTicket(
      CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'update_document',
        targetType: 'document',
        targetId: doc.metadata.id,
        targetPath: doc.metadata.path,
        permissionLevel: PermissionLevel.write,
        baseRevision: sync.revision,
        payloadJson: jsonEncode({'content': '# after execution'}),
      ),
    );
    final result = await container.queueExecutionService.executeApprovedTicket(ticket.id);
    expect(result.status, ExecutionResultStatus.success);
    final loaded = await archive.getDocumentWithContent(doc.metadata.id);
    expect(loaded?.content?.rawMarkdown, contains('after execution'));
  });

  test('approved move_to_trash executes successfully', () async {
    await bindWorkspace();
    await enableTool('move_document_to_trash');
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'Trash Me',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# trash',
      ),
    );
    final ticket = await createApprovedUserTicket(
      CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'move_to_trash',
        targetType: 'document',
        targetId: doc.metadata.id,
        targetPath: doc.metadata.path,
        permissionLevel: PermissionLevel.destructive,
      ),
    );
    final result = await container.queueExecutionService.executeApprovedTicket(ticket.id);
    expect(result.status, ExecutionResultStatus.success);
    final trashItems = await container.trashService.listTrashItems();
    expect(trashItems.any((t) => t.documentId == doc.metadata.id), isTrue);
  });

  test('expired token blocks mcp-agent execution', () async {
    await bindWorkspace();
    await enableTool('update_document');
    final writeToken = await issueToken(PermissionLevel.write);
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'Token Expire',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# token',
      ),
    );
    final sync = await container.syncService.getSyncState(doc.metadata.id);
    final ticket = await container.workQueueService.createTicket(
      CreateWorkQueueTicketInput(
        actor: 'mcp-agent',
        requestedAction: 'update_document',
        targetType: 'document',
        targetId: doc.metadata.id,
        targetPath: doc.metadata.path,
        permissionLevel: PermissionLevel.write,
        permissionTokenId: writeToken,
        baseRevision: sync.revision,
        payloadJson: jsonEncode({'content': '# expired'}),
      ),
    );
    await container.workQueueService.approveTicket(ticket.id);
    await container.permissionTokenService.revokeToken(writeToken);
    final result = await container.queueExecutionService.executeApprovedTicket(ticket.id);
    expect(result.status, ExecutionResultStatus.blocked);
    final updated = (await container.workQueueService.findTicketById(ticket.id))!;
    expect(updated.status, WorkQueueTicketStatus.blocked);
  });

  test('stale revision at execute marks conflict', () async {
    await bindWorkspace();
    await enableTool('update_document');
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'Stale Exec',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# stale',
      ),
    );
    final sync = await container.syncService.getSyncState(doc.metadata.id);
    final ticket = await createApprovedUserTicket(
      CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'update_document',
        targetType: 'document',
        targetId: doc.metadata.id,
        targetPath: doc.metadata.path,
        permissionLevel: PermissionLevel.write,
        baseRevision: sync.revision,
        payloadJson: jsonEncode({'content': '# will conflict'}),
      ),
    );
    await archive.updateDocument(
      UpdateDocumentInput(
        id: doc.metadata.id,
        content: '# bumped revision',
        author: 'user',
        baseRevision: sync.revision,
      ),
    );
    final result = await container.queueExecutionService.executeApprovedTicket(ticket.id);
    expect(result.status, ExecutionResultStatus.conflict);
    final updated = (await container.workQueueService.findTicketById(ticket.id))!;
    expect(updated.status, WorkQueueTicketStatus.conflict);
  });

  test('disabled MCP tool blocks dry-run on approved ticket', () async {
    await bindWorkspace();
    final writeToken = await issueToken(PermissionLevel.write);
    final ticket = await container.workQueueService.createTicket(
      CreateWorkQueueTicketInput(
        actor: 'mcp-agent',
        requestedAction: 'update_document',
        targetType: 'document',
        targetPath: 'documents/Dev/sample.md',
        permissionLevel: PermissionLevel.write,
        permissionTokenId: writeToken,
      ),
    );
    await container.workQueueService.approveTicket(ticket.id);
    expect(
      () => container.queueExecutionService.createDryRunPreview(ticket.id),
      throwsA(isA<StateError>()),
    );
  });

  test('dry-run preview does not store sensitive body', () async {
    await bindWorkspace();
    await enableTool('update_document');
    const sensitive = 'SECRET_DRYRUN_BODY_888';
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      CreateDocumentInput(
        title: 'Dry Run',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: sensitive,
      ),
    );
    final sync = await container.syncService.getSyncState(doc.metadata.id);
    final ticket = await createApprovedUserTicket(
      CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'update_document',
        targetType: 'document',
        targetId: doc.metadata.id,
        targetPath: doc.metadata.path,
        permissionLevel: PermissionLevel.write,
        baseRevision: sync.revision,
        payloadJson: jsonEncode({'content': sensitive}),
      ),
    );
    final preview = await container.queueExecutionService.createDryRunPreview(ticket.id);
    expect(preview.summary.contains('SECRET_DRYRUN_BODY'), isFalse);
    final db = container.databaseService.requireDatabase();
    final rows = await db.query('ticket_dry_run_previews');
    for (final row in rows) {
      final summary = row['summary'] as String? ?? '';
      expect(summary.contains('SECRET_DRYRUN_BODY'), isFalse);
    }
  });

  test('execution log does not store sensitive body', () async {
    await bindWorkspace();
    await enableTool('update_document');
    const sensitive = 'SECRET_EXEC_LOG_BODY_777';
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'Exec Log',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# original',
      ),
    );
    final sync = await container.syncService.getSyncState(doc.metadata.id);
    final ticket = await createApprovedUserTicket(
      CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'update_document',
        targetType: 'document',
        targetId: doc.metadata.id,
        targetPath: doc.metadata.path,
        permissionLevel: PermissionLevel.write,
        baseRevision: sync.revision,
        payloadJson: jsonEncode({'content': sensitive}),
      ),
    );
    await container.queueExecutionService.executeApprovedTicket(ticket.id);
    final db = container.databaseService.requireDatabase();
    final rows = await db.query('ticket_execution_logs');
    expect(rows, isNotEmpty);
    for (final row in rows) {
      final encoded = row.values.join(' ');
      expect(encoded.contains('SECRET_EXEC_LOG_BODY'), isFalse);
    }
  });

  test('cancel approved ticket prevents execution', () async {
    await bindWorkspace();
    await enableTool('create_document');
    final ticket = await container.workQueueService.createTicket(
      const CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: 'documents/Dev/cancel.md',
        permissionLevel: PermissionLevel.write,
        payloadJson: '{"title":"Cancel","relativeDir":"documents/Dev"}',
      ),
    );
    await container.workQueueService.approveTicket(ticket.id);
    await container.workQueueService.cancelTicket(ticket.id);
    final updated = (await container.workQueueService.findTicketById(ticket.id))!;
    expect(updated.status, WorkQueueTicketStatus.cancelled);
    expect(
      () => container.queueExecutionService.executeApprovedTicket(ticket.id),
      throwsA(isA<StateError>()),
    );
  });

  test('dashboard reflects execution summary', () async {
    await bindWorkspace();
    await enableTool('create_document');
    final ticket = await createApprovedUserTicket(
      const CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: 'documents/Dev/dash-exec.md',
        permissionLevel: PermissionLevel.write,
        payloadJson: '{"title":"Dash","relativeDir":"documents/Dev"}',
      ),
    );
    await container.queueExecutionService.executeApprovedTicket(ticket.id);
    final summary = await container.dashboardService.getDashboardSummary();
    expect(summary.executionSummary.completedCount, greaterThanOrEqualTo(1));
    expect(summary.executionSummary.approvedReadyCount, 0);
  });

  test('privacy reflects execution summary', () async {
    await bindWorkspace();
    await enableTool('create_document');
    await createApprovedUserTicket(
      const CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: 'documents/Dev/privacy-exec.md',
        permissionLevel: PermissionLevel.write,
        payloadJson: '{"title":"Privacy","relativeDir":"documents/Dev"}',
      ),
    );
    final before = await container.privacyService.getPrivacySummary();
    expect(before.executionSummary.approvedReadyCount, 1);
  });

  test('approve alone does not mutate document (queue-only regression)', () async {
    await bindWorkspace();
    await enableTool('update_document');
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'No Direct',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# unchanged by approve',
      ),
    );
    final before = await archive.getDocumentWithContent(doc.metadata.id);
    final sync = await container.syncService.getSyncState(doc.metadata.id);
    final writeToken = await issueToken(PermissionLevel.write);
    final ticket = await container.workQueueService.createTicket(
      CreateWorkQueueTicketInput(
        actor: 'mcp-agent',
        requestedAction: 'update_document',
        targetType: 'document',
        targetId: doc.metadata.id,
        targetPath: doc.metadata.path,
        permissionLevel: PermissionLevel.write,
        permissionTokenId: writeToken,
        baseRevision: sync.revision,
        payloadJson: jsonEncode({'content': '# should not apply yet'}),
      ),
    );
    await container.workQueueService.approveTicket(ticket.id);
    final after = await archive.getDocumentWithContent(doc.metadata.id);
    expect(after?.content?.rawMarkdown, before?.content?.rawMarkdown);
    expect((await container.workQueueService.findTicketById(ticket.id))!.status,
        WorkQueueTicketStatus.approved);
  });

  test('Sprint 05 approve atomicity regression', () async {
    await bindWorkspace();
    final queue = container.extractionQueueService;
    final archive = container.personalArchiveService;
    final candidate = await queue.enqueueCandidate(
      const CreateExtractionCandidateInput(
        candidateType: 'approved',
        candidateTitle: 'S8 regression',
        candidateContent: 'body',
      ),
    );
    Object? approveError;
    Object? editError;
    await Future.wait([
      () async {
        try {
          await queue.approveCandidate(candidate.id);
        } catch (e) {
          approveError = e;
        }
      }(),
      () async {
        try {
          await queue.editAndApproveCandidate(
            EditExtractionCandidateInput(
              candidateId: candidate.id,
              title: 'edited',
              content: 'edited',
            ),
          );
        } catch (e) {
          editError = e;
        }
      }(),
    ]);
    expect((await archive.listItems()).length, 1);
    expect(approveError != null || editError != null, isTrue);
  });

  test('Sprint 06 LLM export active-only regression', () async {
    await bindWorkspace();
    final archive = container.personalArchiveService;
    final export = container.llmSelfInfoExportService;
    await archive.createManualItem(
      const CreatePersonalArchiveItemInput(
        itemType: 'profile',
        title: 'Active S8',
        content: 'INCLUDE_S8',
      ),
    );
    final result = await export.buildPreview();
    expect(result.previewMarkdown, contains('INCLUDE_S8'));
    expect(result.excludedPendingCount, 0);
  });

  test('Sprint 07 MCP enqueue without direct execution regression', () async {
    await bindWorkspace();
    await enableTool('update_document');
    final writeToken = await issueToken(PermissionLevel.write);
    final ticket = await container.mcpBridgeStatusService.enqueueToolRequest(
      McpToolRequest(
        toolName: 'update_document',
        actor: 'mcp-agent',
        targetPath: 'documents/Dev/sample.md',
        permissionTokenId: writeToken,
      ),
    );
    expect(ticket.status, WorkQueueTicketStatus.pending);
    expect(
      () => container.queueExecutionService.executeApprovedTicket(ticket.id),
      throwsA(isA<StateError>()),
    );
  });

  test('execution writes audit log without sensitive payload', () async {
    await bindWorkspace();
    await enableTool('create_document');
    const sensitive = 'SECRET_AUDIT_BODY_666';
    final ticket = await createApprovedUserTicket(
      CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: 'documents/Dev/audit-exec.md',
        permissionLevel: PermissionLevel.write,
        payloadJson: jsonEncode({
          'title': 'Audit Exec',
          'relativeDir': 'documents/Dev',
          'initialContent': sensitive,
        }),
      ),
    );
    await container.queueExecutionService.executeApprovedTicket(ticket.id);
    final db = container.databaseService.requireDatabase();
    final auditRows = await db.query(
      'audit_logs',
      where: "action = 'execute_ticket'",
    );
    expect(auditRows, isNotEmpty);
    for (final row in auditRows) {
      final detail = row['detail_json'] as String? ?? '';
      expect(detail.contains('SECRET_AUDIT_BODY'), isFalse);
    }
  });

  test('create_document rejects overwrite of existing path', () async {
    await bindWorkspace();
    await enableTool('create_document');
    final archive = container.archiveService;
    await archive.createDocument(
      const CreateDocumentInput(
        title: 'Existing',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# existing',
      ),
    );
    final ticket = await createApprovedUserTicket(
      const CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: 'documents/Dev/existing.md',
        permissionLevel: PermissionLevel.write,
        payloadJson: '{"title":"Existing","relativeDir":"documents/Dev","type":"Dev"}',
      ),
    );
    final result = await container.queueExecutionService.executeApprovedTicket(ticket.id);
    expect(result.status, ExecutionResultStatus.failed);
    expect(result.errorCode, 'file_exists');
  });

  test('failed update leaves original file content intact', () async {
    await bindWorkspace();
    await enableTool('update_document');
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'Rollback',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# keep this',
      ),
    );
    final sync = await container.syncService.getSyncState(doc.metadata.id);
    final ticket = await createApprovedUserTicket(
      CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'update_document',
        targetType: 'document',
        targetId: doc.metadata.id,
        targetPath: doc.metadata.path,
        permissionLevel: PermissionLevel.write,
        baseRevision: sync.revision,
        payloadJson: jsonEncode({'content': '# replaced'}),
      ),
    );
    await archive.updateDocument(
      UpdateDocumentInput(
        id: doc.metadata.id,
        content: '# bumped',
        author: 'user',
        baseRevision: sync.revision,
      ),
    );
    final result = await container.queueExecutionService.executeApprovedTicket(ticket.id);
    expect(result.status, ExecutionResultStatus.conflict);
    final loaded = await archive.getDocumentWithContent(doc.metadata.id);
    expect(loaded?.content?.rawMarkdown, contains('bumped'));
    expect(loaded?.content?.rawMarkdown, isNot(contains('replaced')));
  });

  test('listExecutionLogs returns result for ticket', () async {
    await bindWorkspace();
    await enableTool('create_document');
    final ticket = await createApprovedUserTicket(
      const CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: 'documents/Dev/log-list.md',
        permissionLevel: PermissionLevel.write,
        payloadJson: '{"title":"Log List","relativeDir":"documents/Dev"}',
      ),
    );
    await container.queueExecutionService.executeApprovedTicket(ticket.id);
    final logs = await container.queueExecutionService.listExecutionLogs(ticket.id);
    expect(logs.length, 1);
    expect(logs.first.resultStatus, ExecutionResultStatus.success);
  });
}
