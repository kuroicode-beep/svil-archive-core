// queue_execution_service_impl.dart — ticket dry-run / execution 구현

import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/ticket_execution.dart';
import '../../domain/models/work_queue.dart';
import '../../domain/services/conflict_guard_service.dart';
import '../../domain/services/mcp_tool_registry_service.dart';
import '../../domain/services/permission_token_service.dart';
import '../../domain/services/queue_execution_service.dart';
import '../../domain/services/safe_apply_service.dart';
import '../../domain/services/sync_service.dart';
import '../../domain/services/work_queue_service.dart';
import '../db/database_service_impl.dart';

/// Sprint 08 실행 허용 action 목록.
const Set<String> kExecutableTicketActions = {
  'create_document',
  'update_document',
  'update_metadata',
  'move_to_trash',
  'move_document_to_trash',
};

class QueueExecutionServiceImpl implements QueueExecutionService {
  final DatabaseServiceImpl _databaseService;
  final WorkQueueService _workQueueService;
  final SafeApplyService _safeApplyService;
  final ConflictGuardService _conflictGuard;
  final PermissionTokenService _permissionTokenService;
  final McpToolRegistryService _toolRegistry;
  final SyncService _syncService;
  final Uuid _uuid = const Uuid();

  QueueExecutionServiceImpl({
    required DatabaseServiceImpl databaseService,
    required WorkQueueService workQueueService,
    required SafeApplyService safeApplyService,
    required ConflictGuardService conflictGuard,
    required PermissionTokenService permissionTokenService,
    required McpToolRegistryService toolRegistry,
    required SyncService syncService,
  })  : _databaseService = databaseService,
        _workQueueService = workQueueService,
        _safeApplyService = safeApplyService,
        _conflictGuard = conflictGuard,
        _permissionTokenService = permissionTokenService,
        _toolRegistry = toolRegistry,
        _syncService = syncService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<DryRunPreview> createDryRunPreview(String ticketId) async {
    final ticket = await _requireApprovedTicket(ticketId);
    final validation = await _validateBeforeExecution(ticket);
    if (validation != null) {
      throw StateError(validation.message);
    }

    final summary = await _buildDryRunSummary(ticket);
    final risk = _riskLevelFor(ticket);
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final expires = now.add(const Duration(minutes: 30));
    await _db.insert('ticket_dry_run_previews', {
      'id': id,
      'ticket_id': ticketId,
      'summary': summary,
      'risk_level': risk.name,
      'preview_status': DryRunPreviewStatus.ready.name,
      'created_at': now.toIso8601String(),
      'expires_at': expires.toIso8601String(),
    });
    return DryRunPreview(
      id: id,
      ticketId: ticketId,
      summary: summary,
      riskLevel: risk,
      previewStatus: DryRunPreviewStatus.ready,
      createdAt: now.toLocal(),
      expiresAt: expires.toLocal(),
    );
  }

  @override
  Future<TicketExecutionResult> executeApprovedTicket(String ticketId) async {
    final ticket = await _requireApprovedTicket(ticketId);
    final validation = await _validateBeforeExecution(ticket);
    if (validation != null) {
      await _setTicketStatus(ticketId, validation.status, validation.message);
      final result = TicketExecutionResult(
        ticketId: ticketId,
        status: _executionStatusFromTicket(validation.status),
        targetPath: ticket.targetPath,
        errorCode: 'pre_validation_failed',
        errorMessage: validation.message,
      );
      await _writeExecutionLog(ticket, result);
      return result;
    }

    final claimed = await _claimApprovedForRunning(ticketId);
    if (!claimed) {
      throw StateError('Ticket is not approved: $ticketId');
    }

    SafeApplyResult applyResult;
    try {
      applyResult = await _dispatchApply(ticket);
    } catch (e) {
      await _setTicketStatus(ticketId, WorkQueueTicketStatus.failed, e.toString());
      final result = TicketExecutionResult(
        ticketId: ticketId,
        status: ExecutionResultStatus.failed,
        targetPath: ticket.targetPath,
        errorCode: 'execution_exception',
        errorMessage: e.toString(),
      );
      await _writeExecutionLog(ticket, result);
      return result;
    }

    if (!applyResult.success) {
      final newStatus = _statusFromApplyError(applyResult.errorCode, applyResult.errorMessage);
      await _setTicketStatus(ticketId, newStatus, applyResult.errorMessage);
      final result = TicketExecutionResult(
        ticketId: ticketId,
        status: _executionStatusFromTicket(newStatus),
        targetPath: applyResult.targetPath ?? ticket.targetPath,
        documentId: applyResult.documentId,
        revisionBefore: applyResult.revisionBefore,
        revisionAfter: applyResult.revisionAfter,
        errorCode: applyResult.errorCode,
        errorMessage: applyResult.errorMessage,
      );
      await _writeExecutionLog(ticket, result);
      return result;
    }

    await _setTicketStatus(ticketId, WorkQueueTicketStatus.completed, null);
    final result = TicketExecutionResult(
      ticketId: ticketId,
      status: ExecutionResultStatus.success,
      targetPath: applyResult.targetPath ?? ticket.targetPath,
      documentId: applyResult.documentId,
      revisionBefore: applyResult.revisionBefore,
      revisionAfter: applyResult.revisionAfter,
    );
    await _writeExecutionLog(ticket, result);
    await _auditExecution(ticketId, 'execute_ticket', result.status.name);
    return result;
  }

  @override
  Future<List<TicketExecutionLog>> listExecutionLogs(String ticketId) async {
    final rows = await _db.query(
      'ticket_execution_logs',
      where: 'ticket_id = ?',
      whereArgs: [ticketId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_mapExecutionLog).toList();
  }

  @override
  Future<QueueExecutionSummary> getExecutionSummary() async {
    Future<int> count(String status) async {
      return Sqflite.firstIntValue(
            await _db.rawQuery(
              'SELECT COUNT(*) FROM work_queue_tickets WHERE status = ?',
              [status],
            ),
          ) ??
          0;
    }

    return QueueExecutionSummary(
      approvedReadyCount: await count(WorkQueueTicketStatus.approved.name),
      executionFailedCount: await count(WorkQueueTicketStatus.failed.name),
      conflictCount: await count(WorkQueueTicketStatus.conflict.name),
      completedCount: await count(WorkQueueTicketStatus.completed.name),
    );
  }

  /// approved ticket을 로드한다.
  Future<WorkQueueTicket> _requireApprovedTicket(String ticketId) async {
    final ticket = await _workQueueService.findTicketById(ticketId);
    if (ticket == null) {
      throw StateError('Ticket not found: $ticketId');
    }
    if (ticket.status != WorkQueueTicketStatus.approved) {
      throw StateError('Ticket is not approved: $ticketId');
    }
    return ticket;
  }

  /// 실행 직전 재검증 결과.
  ({String message, WorkQueueTicketStatus status})? _validationFailure(
    String message,
    ConflictGuardAction action,
  ) {
    if (action == ConflictGuardAction.conflict) {
      return (message: message, status: WorkQueueTicketStatus.conflict);
    }
    return (message: message, status: WorkQueueTicketStatus.blocked);
  }

  /// 실행 직전 재검증을 수행한다.
  Future<({String message, WorkQueueTicketStatus status})?> _validateBeforeExecution(
    WorkQueueTicket ticket,
  ) async {
    if (!kExecutableTicketActions.contains(ticket.requestedAction)) {
      return (message: 'Action not in execution allowlist', status: WorkQueueTicketStatus.blocked);
    }

    if (_requiresBaseRevision(ticket.requestedAction) && ticket.baseRevision == null) {
      return (
        message: 'baseRevision required for update execution',
        status: WorkQueueTicketStatus.blocked,
      );
    }

    final toolName = _toolNameForAction(ticket.requestedAction);
    if (toolName != null) {
      final enabled = await _toolRegistry.isToolEnabled(toolName);
      if (!enabled) {
        return (
          message: 'MCP tool is disabled: $toolName',
          status: WorkQueueTicketStatus.blocked,
        );
      }
    }

    if (ticket.actor != 'user') {
      final tokenId = ticket.permissionTokenId;
      if (tokenId == null || tokenId.isEmpty) {
        return (message: 'Permission token required', status: WorkQueueTicketStatus.blocked);
      }
      final valid = await _permissionTokenService.validateActiveToken(
        tokenId: tokenId,
        tokenType: ticket.permissionLevel,
        actor: ticket.actor,
      );
      if (!valid) {
        return (
          message: 'Invalid or expired permission token',
          status: WorkQueueTicketStatus.blocked,
        );
      }
    }

    if (ticket.permissionLevel == PermissionLevel.destructive) {
      final guard = await _conflictGuard.validateDestructiveRequest(
        DestructiveRequest(
          documentId: ticket.targetId,
          relativePath: ticket.targetPath,
          actor: ticket.actor,
          action: ticket.requestedAction,
        ),
      );
      if (guard.action == ConflictGuardAction.block ||
          guard.action == ConflictGuardAction.conflict) {
        return _validationFailure(guard.message, guard.action);
      }
    } else if (ticket.permissionLevel == PermissionLevel.write ||
        ticket.permissionLevel == PermissionLevel.personal ||
        ticket.permissionLevel == PermissionLevel.admin) {
      final guard = await _conflictGuard.validateWriteRequest(
        DocumentWriteRequest(
          documentId: ticket.targetId,
          relativePath: ticket.targetPath,
          baseRevision: ticket.baseRevision,
          actor: ticket.actor,
        ),
      );
      if (guard.action == ConflictGuardAction.block ||
          guard.action == ConflictGuardAction.conflict) {
        return _validationFailure(guard.message, guard.action);
      }
    }

    return null;
  }

  /// update 실행에 baseRevision이 필요한 action인지 확인한다.
  bool _requiresBaseRevision(String action) =>
      action == 'update_document' || action == 'update_metadata';

  /// action에 대응하는 MCP tool 이름을 반환한다.
  String? _toolNameForAction(String action) {
    switch (action) {
      case 'create_document':
        return 'create_document';
      case 'update_document':
      case 'update_metadata':
        return 'update_document';
      case 'move_to_trash':
      case 'move_document_to_trash':
        return 'move_document_to_trash';
      default:
        return null;
    }
  }

  /// dry-run 요약 문자열을 생성한다 (본문 미포함).
  Future<String> _buildDryRunSummary(WorkQueueTicket ticket) async {
    final buffer = StringBuffer()
      ..writeln('action: ${ticket.requestedAction}')
      ..writeln('target: ${ticket.targetPath ?? ticket.targetId ?? '-'}');

    if (ticket.targetId != null) {
      final sync = await _syncService.getSyncState(ticket.targetId!);
      buffer.writeln('current revision: ${sync.revision}');
      if (ticket.baseRevision != null) {
        buffer.writeln('expected base revision: ${ticket.baseRevision}');
      }
    }

    if (ticket.permissionLevel == PermissionLevel.destructive) {
      buffer.writeln('risk: 휴지통 이동 (영구 삭제 아님)');
    }
    return buffer.toString().trim();
  }

  /// ticket risk level을 반환한다.
  DryRunRiskLevel _riskLevelFor(WorkQueueTicket ticket) {
    if (ticket.permissionLevel == PermissionLevel.destructive) {
      return DryRunRiskLevel.destructive;
    }
    if (ticket.permissionLevel == PermissionLevel.write) {
      return DryRunRiskLevel.medium;
    }
    return DryRunRiskLevel.low;
  }

  /// payload JSON을 Map으로 파싱한다.
  Map<String, dynamic> _parsePayload(WorkQueueTicket ticket) {
    final raw = ticket.payloadJson;
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {}
    return {};
  }

  /// ticket action에 따라 safe apply를 실행한다.
  Future<SafeApplyResult> _dispatchApply(WorkQueueTicket ticket) async {
    final payload = _parsePayload(ticket);
    switch (ticket.requestedAction) {
      case 'create_document':
        return _safeApplyService.createDocument(
          SafeCreateDocumentRequest(
            ticketId: ticket.id,
            actor: ticket.actor,
            title: payload['title'] as String? ?? 'Untitled',
            relativeDir: payload['relativeDir'] as String? ??
                ticket.targetPath?.replaceAll(RegExp(r'/[^/]+\.md$'), '') ??
                'documents/Dev',
            type: payload['type'] as String? ?? 'Dev',
            initialContent: payload['initialContent'] as String? ?? '',
            permissionTokenId: ticket.permissionTokenId,
          ),
        );
      case 'update_document':
      case 'update_metadata':
        final docId = ticket.targetId ?? payload['documentId'] as String?;
        if (docId == null) {
          return const SafeApplyResult(
            success: false,
            errorCode: 'missing_target',
            errorMessage: 'Document id required',
          );
        }
        if (ticket.baseRevision == null) {
          return const SafeApplyResult(
            success: false,
            errorCode: 'missing_base_revision',
            errorMessage: 'baseRevision required for update execution',
          );
        }
        return _safeApplyService.updateDocument(
          SafeUpdateDocumentRequest(
            ticketId: ticket.id,
            actor: ticket.actor,
            documentId: docId,
            baseRevision: ticket.baseRevision!,
            title: payload['title'] as String?,
            content: payload['content'] as String?,
            permissionTokenId: ticket.permissionTokenId,
          ),
        );
      case 'move_to_trash':
      case 'move_document_to_trash':
        final docId = ticket.targetId ?? payload['documentId'] as String?;
        if (docId == null) {
          return const SafeApplyResult(
            success: false,
            errorCode: 'missing_target',
            errorMessage: 'Document id required',
          );
        }
        return _safeApplyService.moveDocumentToTrash(
          SafeTrashDocumentRequest(
            ticketId: ticket.id,
            actor: ticket.actor,
            documentId: docId,
            permissionTokenId: ticket.permissionTokenId,
          ),
        );
      default:
        return const SafeApplyResult(
          success: false,
          errorCode: 'unsupported_action',
          errorMessage: 'Unsupported action',
        );
    }
  }

  /// approved → running 상태 전이를 원자적으로 시도한다.
  Future<bool> _claimApprovedForRunning(String ticketId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = await _db.update(
      'work_queue_tickets',
      {
        'status': WorkQueueTicketStatus.running.name,
        'updated_at': now,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [ticketId, WorkQueueTicketStatus.approved.name],
    );
    return updated == 1;
  }

  /// ticket 상태를 갱신한다.
  Future<void> _setTicketStatus(
    String ticketId,
    WorkQueueTicketStatus status,
    String? errorMessage,
  ) async {
    await _db.update(
      'work_queue_tickets',
      {
        'status': status.name,
        'error_message': errorMessage,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [ticketId],
    );
  }

  /// apply 오류를 ticket status로 변환한다.
  WorkQueueTicketStatus _statusFromApplyError(String? code, String? message) {
    final combined = '${code ?? ''} ${message ?? ''}'.toLowerCase();
    if (combined.contains('revision conflict') || combined.contains('conflict')) {
      return WorkQueueTicketStatus.conflict;
    }
    return WorkQueueTicketStatus.failed;
  }

  /// ticket status를 execution result status로 변환한다.
  ExecutionResultStatus _executionStatusFromTicket(WorkQueueTicketStatus status) {
    switch (status) {
      case WorkQueueTicketStatus.conflict:
        return ExecutionResultStatus.conflict;
      case WorkQueueTicketStatus.blocked:
        return ExecutionResultStatus.blocked;
      case WorkQueueTicketStatus.completed:
        return ExecutionResultStatus.success;
      default:
        return ExecutionResultStatus.failed;
    }
  }

  /// execution log row를 기록한다.
  Future<void> _writeExecutionLog(
    WorkQueueTicket ticket,
    TicketExecutionResult result,
  ) async {
    await _db.insert('ticket_execution_logs', {
      'id': _uuid.v4(),
      'ticket_id': ticket.id,
      'action': ticket.requestedAction,
      'target_path': result.targetPath ?? ticket.targetPath,
      'result_status': result.status.name,
      'error_code': result.errorCode,
      'error_message': result.errorMessage,
      'revision_before': result.revisionBefore,
      'revision_after': result.revisionAfter,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// audit log에 실행 결과 ID만 기록한다.
  Future<void> _auditExecution(String ticketId, String action, String result) async {
    await _db.insert('audit_logs', {
      'id': _uuid.v4(),
      'actor': 'user',
      'action': action,
      'target_type': 'work_queue_ticket',
      'target_id': ticketId,
      'detail_json': '{"result":"$result"}',
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// DB row를 TicketExecutionLog로 변환한다.
  TicketExecutionLog _mapExecutionLog(Map<String, Object?> row) {
    return TicketExecutionLog(
      id: row['id'] as String,
      ticketId: row['ticket_id'] as String,
      action: row['action'] as String,
      targetPath: row['target_path'] as String?,
      resultStatus: ExecutionResultStatus.values.firstWhere(
        (s) => s.name == (row['result_status'] as String? ?? 'failed'),
        orElse: () => ExecutionResultStatus.failed,
      ),
      errorCode: row['error_code'] as String?,
      errorMessage: row['error_message'] as String?,
      revisionBefore: row['revision_before'] as int?,
      revisionAfter: row['revision_after'] as int?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}
