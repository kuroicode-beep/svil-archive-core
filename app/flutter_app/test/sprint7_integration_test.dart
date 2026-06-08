// sprint7_integration_test.dart — MCP Bridge / Work Queue / Conflict Guard 테스트

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/db/migrations.dart';
import 'package:sac_app/domain/models/personal_archive.dart';
import 'package:sac_app/domain/services/archive_service.dart';
import 'package:sac_app/domain/models/work_queue.dart';

void main() {
  late Directory tempDir;
  late SacContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sac_sprint7_test_');
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
      name: 'Sprint7 WS',
      rootPath: p.join(tempDir.path, 'SAC S7'),
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

  test('migration v6 applies work queue MCP and execution tables', () async {
    await bindWorkspace();
    expect(await container.databaseService.getSchemaVersion(), kSacSchemaVersion);
    final db = container.databaseService.requireDatabase();
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final names = tables.map((r) => r['name'] as String).toSet();
    expect(names.contains('work_queue_tickets'), isTrue);
    expect(names.contains('mcp_tool_settings'), isTrue);
    expect(names.contains('permission_tokens'), isTrue);
    expect(names.contains('ticket_execution_logs'), isTrue);
    expect(names.contains('ticket_dry_run_previews'), isTrue);
  });

  test('work queue ticket creation with pending status', () async {
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
    expect(ticket.status, WorkQueueTicketStatus.pending);
    expect(ticket.permissionLevel, PermissionLevel.write);
  });

  test('read and write permission levels are separated', () async {
    await bindWorkspace();
    final readTicket = await container.workQueueService.createTicket(
      const CreateWorkQueueTicketInput(
        actor: 'mcp-agent',
        requestedAction: 'get_document',
        targetType: 'document',
        permissionLevel: PermissionLevel.read,
      ),
    );
    final writeToken = await issueToken(PermissionLevel.write);
    final writeTicket = await container.workQueueService.createTicket(
      CreateWorkQueueTicketInput(
        actor: 'mcp-agent',
        requestedAction: 'update_document',
        targetType: 'document',
        targetPath: 'documents/Dev/sample.md',
        permissionLevel: PermissionLevel.write,
        permissionTokenId: writeToken,
      ),
    );
    expect(readTicket.permissionLevel, PermissionLevel.read);
    expect(writeTicket.permissionLevel, PermissionLevel.write);
  });

  test('destructive request creates pending ticket', () async {
    await bindWorkspace();
    final destructiveToken = await issueToken(PermissionLevel.destructive);
    final ticket = await container.workQueueService.createTicket(
      CreateWorkQueueTicketInput(
        actor: 'mcp-agent',
        requestedAction: 'move_document_to_trash',
        targetType: 'document',
        targetPath: 'documents/Dev/sample.md',
        permissionLevel: PermissionLevel.destructive,
        permissionTokenId: destructiveToken,
      ),
    );
    expect(ticket.status, WorkQueueTicketStatus.pending);
    expect(ticket.permissionLevel, PermissionLevel.destructive);
  });

  test('disabled MCP tool blocks enqueue', () async {
    await bindWorkspace();
    expect(
      () => container.mcpBridgeStatusService.enqueueToolRequest(
        const McpToolRequest(toolName: 'update_document', actor: 'mcp-agent'),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('write request queues without modifying document', () async {
    await bindWorkspace();
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'Queue Test',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# Original\n\nunchanged',
      ),
    );
    final before = await archive.getDocumentWithContent(doc.metadata.id);
    final writeToken = await issueToken(PermissionLevel.write);
    await container.workQueueService.createTicket(
      CreateWorkQueueTicketInput(
        actor: 'mcp-agent',
        requestedAction: 'update_document',
        targetType: 'document',
        targetId: doc.metadata.id,
        targetPath: doc.metadata.path,
        permissionLevel: PermissionLevel.write,
        permissionTokenId: writeToken,
      ),
    );
    final after = await archive.getDocumentWithContent(doc.metadata.id);
    expect(after?.content?.rawMarkdown, before?.content?.rawMarkdown);
    expect((await container.workQueueService.listPendingTickets()).length, 1);
  });

  test('conflict guard blocks stale revision', () async {
    await bindWorkspace();
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'Revision Test',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# v1',
      ),
    );
    final sync = await container.syncService.getSyncState(doc.metadata.id);
    final result = await container.conflictGuardService.validateWriteRequest(
      DocumentWriteRequest(
        documentId: doc.metadata.id,
        relativePath: doc.metadata.path,
        baseRevision: sync.revision - 1,
        actor: 'mcp-agent',
      ),
    );
    expect(result.action, ConflictGuardAction.conflict);
  });

  test('conflict guard blocks path traversal', () async {
    await bindWorkspace();
    final result = await container.conflictGuardService.validateWriteRequest(
      const DocumentWriteRequest(
        relativePath: '../../outside.md',
        actor: 'mcp-agent',
      ),
    );
    expect(result.action, ConflictGuardAction.block);
  });

  test('conflict guard blocks trashed document write', () async {
    await bindWorkspace();
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'Trash Test',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# trash me',
      ),
    );
    await archive.moveDocumentToTrash(doc.metadata.id);
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
      ),
    );
    expect(ticket.status, WorkQueueTicketStatus.blocked);
  });

  test('work queue approve and reject change status', () async {
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
    final all = await container.workQueueService.listAllTickets();
    expect(all.firstWhere((t) => t.id == ticket.id).status, WorkQueueTicketStatus.approved);

    final writeToken2 = await issueToken(PermissionLevel.write);
    final ticket2 = await container.workQueueService.createTicket(
      CreateWorkQueueTicketInput(
        actor: 'mcp-agent',
        requestedAction: 'create_document',
        targetType: 'document',
        targetPath: 'documents/Dev/new.md',
        permissionLevel: PermissionLevel.write,
        permissionTokenId: writeToken2,
      ),
    );
    await container.workQueueService.rejectTicket(ticket2.id, 'not needed');
    final rejected = (await container.workQueueService.listAllTickets())
        .firstWhere((t) => t.id == ticket2.id);
    expect(rejected.status, WorkQueueTicketStatus.rejected);
  });

  test('dashboard reflects MCP and queue status', () async {
    await bindWorkspace();
    final writeToken = await issueToken(PermissionLevel.write);
    await container.workQueueService.createTicket(
      CreateWorkQueueTicketInput(
        actor: 'mcp-agent',
        requestedAction: 'update_document',
        targetType: 'document',
        targetPath: 'documents/Dev/sample.md',
        permissionLevel: PermissionLevel.write,
        permissionTokenId: writeToken,
      ),
    );
    final summary = await container.dashboardService.getDashboardSummary();
    expect(summary.mcpBridgeStatus.localOnly, isTrue);
    expect(summary.workQueueSummary.pendingCount, greaterThanOrEqualTo(1));
    expect(summary.disabledMcpToolCount, greaterThan(0));
  });

  test('privacy reflects MCP local only and token counts', () async {
    await bindWorkspace();
    await container.permissionTokenService.issueToken(
      tokenType: PermissionLevel.write,
      actor: 'user',
      scope: 'workspace',
    );
    final privacy = await container.privacyService.getPrivacySummary();
    expect(privacy.mcpPrivacy.localOnly, isTrue);
    expect(privacy.mcpPrivacy.remoteMcpEnabled, isFalse);
    expect(privacy.mcpPrivacy.writeTokenCount, 1);
    expect(privacy.mcpPrivacy.disabledToolCount, greaterThan(0));
  });

  test('audit log does not store sensitive body content', () async {
    await bindWorkspace();
    const sensitive = 'SECRET_PERSONAL_BODY_12345';
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      CreateDocumentInput(
        title: 'Sensitive',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: sensitive,
      ),
    );
    final writeToken = await issueToken(PermissionLevel.write);
    await container.workQueueService.createTicket(
      CreateWorkQueueTicketInput(
        actor: 'mcp-agent',
        requestedAction: 'update_document',
        targetType: 'document',
        targetId: doc.metadata.id,
        targetPath: doc.metadata.path,
        permissionLevel: PermissionLevel.write,
        permissionTokenId: writeToken,
      ),
    );
    final db = container.databaseService.requireDatabase();
    final ticketRows = await db.query('work_queue_tickets');
    for (final row in ticketRows) {
      final encoded = row.values.join(' ');
      expect(encoded.contains('SECRET_PERSONAL_BODY'), isFalse);
    }
    final auditRows = await db.query('audit_logs');
    for (final row in auditRows) {
      final detail = row['detail_json'] as String? ?? '';
      expect(detail.contains('SECRET_PERSONAL_BODY'), isFalse);
      expect(detail, '{}');
    }
  });

  test('enabled MCP tool enqueues ticket without direct execution', () async {
    await bindWorkspace();
    await container.mcpToolRegistryService.setToolEnabled('update_document', true);
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
    expect(ticket.requestedAction, 'update_document');
  });

  test('MCP write enqueue without token is blocked', () async {
    await bindWorkspace();
    await container.mcpToolRegistryService.setToolEnabled('update_document', true);
    final ticket = await container.mcpBridgeStatusService.enqueueToolRequest(
      const McpToolRequest(
        toolName: 'update_document',
        actor: 'mcp-agent',
        targetPath: 'documents/Dev/sample.md',
      ),
    );
    expect(ticket.status, WorkQueueTicketStatus.blocked);
  });

  test('destructive enqueue without token is blocked', () async {
    await bindWorkspace();
    await container.mcpToolRegistryService.setToolEnabled('move_document_to_trash', true);
    final ticket = await container.mcpBridgeStatusService.enqueueToolRequest(
      const McpToolRequest(
        toolName: 'move_document_to_trash',
        actor: 'mcp-agent',
        targetPath: 'documents/Dev/sample.md',
      ),
    );
    expect(ticket.status, WorkQueueTicketStatus.blocked);
  });

  test('stale baseRevision MCP enqueue creates conflict ticket', () async {
    await bindWorkspace();
    await container.mcpToolRegistryService.setToolEnabled('update_document', true);
    final writeToken = await issueToken(PermissionLevel.write);
    final archive = container.archiveService;
    final doc = await archive.createDocument(
      const CreateDocumentInput(
        title: 'Stale MCP',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# stale test',
      ),
    );
    final sync = await container.syncService.getSyncState(doc.metadata.id);
    final ticket = await container.mcpBridgeStatusService.enqueueToolRequest(
      McpToolRequest(
        toolName: 'update_document',
        actor: 'mcp-agent',
        targetId: doc.metadata.id,
        targetPath: doc.metadata.path,
        baseRevision: sync.revision - 1,
        permissionTokenId: writeToken,
      ),
    );
    expect(ticket.status, WorkQueueTicketStatus.conflict);
  });

  test('non-user approve without token is blocked', () async {
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
    expect(
      () => container.workQueueService.approveTicket(
        ticket.id,
        approverActor: 'mcp-agent',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('Sprint 05 approve atomicity regression', () async {
    await bindWorkspace();
    final queue = container.extractionQueueService;
    final archive = container.personalArchiveService;
    final candidate = await queue.enqueueCandidate(
      const CreateExtractionCandidateInput(
        candidateType: 'approved',
        candidateTitle: 'S7 regression',
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
        title: 'Active',
        content: 'INCLUDE_ME',
      ),
    );
    final result = await export.buildPreview();
    expect(result.previewMarkdown, contains('INCLUDE_ME'));
    expect(result.excludedPendingCount, 0);
  });
}
