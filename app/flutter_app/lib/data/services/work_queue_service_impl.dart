// work_queue_service_impl.dart — 작업큐 티켓 SQLite 구현

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/work_queue.dart';
import '../../domain/services/conflict_guard_service.dart';
import '../../domain/services/permission_token_service.dart';
import '../../domain/services/work_queue_service.dart';
import '../db/database_service_impl.dart';

class WorkQueueServiceImpl implements WorkQueueService {
  final DatabaseServiceImpl _databaseService;
  final ConflictGuardService _conflictGuard;
  final PermissionTokenService _permissionTokenService;
  final Uuid _uuid = const Uuid();

  static const _tokenRequiredLevels = {
    PermissionLevel.write,
    PermissionLevel.destructive,
    PermissionLevel.personal,
    PermissionLevel.admin,
  };

  WorkQueueServiceImpl({
    required DatabaseServiceImpl databaseService,
    required ConflictGuardService conflictGuard,
    required PermissionTokenService permissionTokenService,
  })  : _databaseService = databaseService,
        _conflictGuard = conflictGuard,
        _permissionTokenService = permissionTokenService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<WorkQueueTicket> createTicket(CreateWorkQueueTicketInput input) async {
    final tokenResult = await _validatePermissionToken(input);
    if (tokenResult != null) {
      return _insertTicket(input, tokenResult);
    }

    final guardStatus = await _runGuard(input);
    final status = _statusFromGuard(guardStatus);
    final reason = guardStatus?.message ?? input.reason;
    return _insertTicket(
      input,
      guardStatus,
      status: status,
      reason: reason,
      errorMessage: guardStatus?.action == ConflictGuardAction.block ? reason : null,
    );
  }

  /// permission token 요구 수준인지 확인한다.
  bool _requiresPermissionToken(PermissionLevel level) =>
      _tokenRequiredLevels.contains(level);

  /// MCP/AI actor의 permission token을 검증한다.
  Future<ConflictGuardResult?> _validatePermissionToken(
    CreateWorkQueueTicketInput input,
  ) async {
    if (!_requiresPermissionToken(input.permissionLevel)) return null;
    if (input.actor == 'user') return null;

    final tokenId = input.permissionTokenId;
    if (tokenId == null || tokenId.isEmpty) {
      return const ConflictGuardResult(
        action: ConflictGuardAction.block,
        message: 'Permission token required',
      );
    }

    final valid = await _permissionTokenService.validateActiveToken(
      tokenId: tokenId,
      tokenType: input.permissionLevel,
      actor: input.actor,
    );
    if (!valid) {
      return const ConflictGuardResult(
        action: ConflictGuardAction.block,
        message: 'Invalid or expired permission token',
      );
    }
    return null;
  }

  /// permission level에 따라 conflict guard를 실행한다.
  Future<ConflictGuardResult?> _runGuard(CreateWorkQueueTicketInput input) async {
    if (input.permissionLevel == PermissionLevel.read) return null;

    if (input.permissionLevel == PermissionLevel.destructive) {
      return _conflictGuard.validateDestructiveRequest(
        DestructiveRequest(
          documentId: input.targetId,
          relativePath: input.targetPath,
          actor: input.actor,
          action: input.requestedAction,
        ),
      );
    }

    if (input.permissionLevel == PermissionLevel.write ||
        input.permissionLevel == PermissionLevel.personal ||
        input.permissionLevel == PermissionLevel.admin) {
      return _conflictGuard.validateWriteRequest(
        DocumentWriteRequest(
          documentId: input.targetId,
          relativePath: input.targetPath,
          baseRevision: input.baseRevision,
          actor: input.actor,
        ),
      );
    }
    return null;
  }

  /// guard 결과를 ticket status로 변환한다.
  WorkQueueTicketStatus _statusFromGuard(ConflictGuardResult? guard) {
    if (guard == null) return WorkQueueTicketStatus.pending;
    switch (guard.action) {
      case ConflictGuardAction.allow:
        return WorkQueueTicketStatus.pending;
      case ConflictGuardAction.requireApproval:
        return WorkQueueTicketStatus.pending;
      case ConflictGuardAction.block:
        return WorkQueueTicketStatus.blocked;
      case ConflictGuardAction.conflict:
        return WorkQueueTicketStatus.conflict;
    }
  }

  /// ticket row를 DB에 삽입하고 모델을 반환한다.
  Future<WorkQueueTicket> _insertTicket(
    CreateWorkQueueTicketInput input,
    ConflictGuardResult? guard, {
    WorkQueueTicketStatus? status,
    String? reason,
    String? errorMessage,
  }) async {
    final resolvedStatus = status ?? _statusFromGuard(guard);
    final resolvedReason = reason ?? guard?.message ?? input.reason;
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert('work_queue_tickets', {
      'id': id,
      'actor': input.actor,
      'requested_action': input.requestedAction,
      'target_type': input.targetType,
      'target_id': input.targetId,
      'target_path': input.targetPath,
      'permission_level': input.permissionLevel.name,
      'status': resolvedStatus.name,
      'priority': input.priority,
      'reason': resolvedReason,
      'error_message': errorMessage ??
          (guard?.action == ConflictGuardAction.block ? resolvedReason : null),
      'base_revision': input.baseRevision,
      'permission_token_id': input.permissionTokenId,
      'payload_json': input.payloadJson,
      'source_ticket_id': input.sourceTicketId,
      'recovery_kind': input.recoveryKind,
      'created_at': now,
      'updated_at': now,
    });
    await _audit('create_ticket', id);
    return _mapRow({
      'id': id,
      'actor': input.actor,
      'requested_action': input.requestedAction,
      'target_type': input.targetType,
      'target_id': input.targetId,
      'target_path': input.targetPath,
      'permission_level': input.permissionLevel.name,
      'status': resolvedStatus.name,
      'priority': input.priority,
      'reason': resolvedReason,
      'error_message': errorMessage ??
          (guard?.action == ConflictGuardAction.block ? resolvedReason : null),
      'base_revision': input.baseRevision,
      'permission_token_id': input.permissionTokenId,
      'payload_json': input.payloadJson,
      'source_ticket_id': input.sourceTicketId,
      'recovery_kind': input.recoveryKind,
      'created_at': now,
      'updated_at': now,
    });
  }

  @override
  Future<void> cancelTicket(String ticketId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = await _db.update(
      'work_queue_tickets',
      {
        'status': WorkQueueTicketStatus.cancelled.name,
        'updated_at': now,
      },
      where: "id = ? AND status IN ('pending', 'approved')",
      whereArgs: [ticketId],
    );
    if (updated != 1) {
      throw StateError('Ticket cannot be cancelled: $ticketId');
    }
    await _audit('cancel_ticket', ticketId);
  }

  @override
  Future<WorkQueueTicket?> findTicketById(String ticketId) async {
    final rows = await _db.query(
      'work_queue_tickets',
      where: 'id = ?',
      whereArgs: [ticketId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  @override
  Future<List<WorkQueueTicket>> listPendingTickets() async {
    final rows = await _db.query(
      'work_queue_tickets',
      where: "status = ?",
      whereArgs: [WorkQueueTicketStatus.pending.name],
      orderBy: 'created_at DESC',
    );
    return rows.map(_mapRow).toList();
  }

  @override
  Future<List<WorkQueueTicket>> listAllTickets() async {
    final rows = await _db.query(
      'work_queue_tickets',
      orderBy: 'created_at DESC',
    );
    return rows.map(_mapRow).toList();
  }

  @override
  Future<WorkQueueSummary> getSummary() async {
    Future<int> count(String status) async {
      return Sqflite.firstIntValue(
            await _db.rawQuery(
              'SELECT COUNT(*) FROM work_queue_tickets WHERE status = ?',
              [status],
            ),
          ) ??
          0;
    }

    return WorkQueueSummary(
      pendingCount: await count(WorkQueueTicketStatus.pending.name),
      conflictCount: await count(WorkQueueTicketStatus.conflict.name),
      failedCount: await count(WorkQueueTicketStatus.failed.name),
      blockedCount: await count(WorkQueueTicketStatus.blocked.name),
      approvedCount: await count(WorkQueueTicketStatus.approved.name),
      runningCount: await count(WorkQueueTicketStatus.running.name),
      completedCount: await count(WorkQueueTicketStatus.completed.name),
    );
  }

  @override
  Future<void> approveTicket(
    String ticketId, {
    String approverActor = 'user',
    String? permissionTokenId,
  }) async {
    final ticket = await _loadTicket(ticketId);
    if (ticket.status != WorkQueueTicketStatus.pending) {
      throw StateError('Ticket is not pending: $ticketId');
    }

    if (_requiresPermissionToken(ticket.permissionLevel) && approverActor != 'user') {
      final tokenId = permissionTokenId;
      if (tokenId == null || tokenId.isEmpty) {
        throw StateError('Permission token required for approval');
      }
      final valid = await _permissionTokenService.validateActiveToken(
        tokenId: tokenId,
        tokenType: ticket.permissionLevel,
        actor: approverActor,
      );
      if (!valid) {
        throw StateError('Invalid or expired permission token for approval');
      }
    }

    await _updateStatus(ticketId, WorkQueueTicketStatus.approved, onlyFrom: WorkQueueTicketStatus.pending);
    await _audit('approve_ticket', ticketId);
  }

  @override
  Future<void> rejectTicket(String ticketId, String reason) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = await _db.update(
      'work_queue_tickets',
      {
        'status': WorkQueueTicketStatus.rejected.name,
        'reason': reason,
        'updated_at': now,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [ticketId, WorkQueueTicketStatus.pending.name],
    );
    if (updated != 1) {
      throw StateError('Ticket is not pending: $ticketId');
    }
    await _audit('reject_ticket', ticketId);
  }

  @override
  Future<void> markConflict(String ticketId, String reason) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      'work_queue_tickets',
      {
        'status': WorkQueueTicketStatus.conflict.name,
        'reason': reason,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [ticketId],
    );
    await _audit('mark_conflict', ticketId);
  }

  /// ticket을 ID로 조회한다.
  Future<WorkQueueTicket> _loadTicket(String ticketId) async {
    final rows = await _db.query(
      'work_queue_tickets',
      where: 'id = ?',
      whereArgs: [ticketId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Ticket not found: $ticketId');
    }
    return _mapRow(rows.first);
  }

  /// ticket 상태를 조건부로 갱신한다.
  Future<void> _updateStatus(
    String ticketId,
    WorkQueueTicketStatus newStatus, {
    WorkQueueTicketStatus? onlyFrom,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = await _db.update(
      'work_queue_tickets',
      {
        'status': newStatus.name,
        'updated_at': now,
      },
      where: onlyFrom != null ? 'id = ? AND status = ?' : 'id = ?',
      whereArgs: onlyFrom != null ? [ticketId, onlyFrom.name] : [ticketId],
    );
    if (updated != 1) {
      throw StateError('Ticket status update failed: $ticketId');
    }
  }

  /// 감사 로그에 ticket ID만 기록한다.
  Future<void> _audit(String action, String ticketId) async {
    await _db.insert('audit_logs', {
      'id': _uuid.v4(),
      'actor': 'user',
      'action': action,
      'target_type': 'work_queue_ticket',
      'target_id': ticketId,
      'detail_json': '{}',
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// DB row를 WorkQueueTicket으로 변환한다.
  WorkQueueTicket _mapRow(Map<String, Object?> row) {
    return WorkQueueTicket(
      id: row['id'] as String,
      actor: row['actor'] as String,
      requestedAction: row['requested_action'] as String,
      targetType: row['target_type'] as String,
      targetId: row['target_id'] as String?,
      targetPath: row['target_path'] as String?,
      permissionLevel: PermissionLevel.values.firstWhere(
        (p) => p.name == (row['permission_level'] as String? ?? 'read'),
        orElse: () => PermissionLevel.read,
      ),
      status: WorkQueueTicketStatus.values.firstWhere(
        (s) => s.name == (row['status'] as String? ?? 'pending'),
        orElse: () => WorkQueueTicketStatus.pending,
      ),
      priority: row['priority'] as int? ?? 5,
      reason: row['reason'] as String?,
      errorMessage: row['error_message'] as String?,
      baseRevision: row['base_revision'] as int?,
      permissionTokenId: row['permission_token_id'] as String?,
      payloadJson: row['payload_json'] as String?,
      sourceTicketId: row['source_ticket_id'] as String?,
      recoveryKind: row['recovery_kind'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }
}
