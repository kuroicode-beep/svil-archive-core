// execution_recovery_service_impl.dart — 실행 티켓 복구 구현

import 'package:uuid/uuid.dart';

import '../../domain/models/execution_recovery.dart';
import '../../domain/models/ticket_execution.dart';
import '../../domain/models/work_queue.dart';
import '../../domain/services/execution_recovery_service.dart';
import '../../domain/services/work_queue_service.dart';
import '../db/database_service_impl.dart';

/// 복구 대상 ticket status.
const Set<WorkQueueTicketStatus> kRecoverableTicketStatuses = {
  WorkQueueTicketStatus.failed,
  WorkQueueTicketStatus.blocked,
  WorkQueueTicketStatus.conflict,
};

class ExecutionRecoveryServiceImpl implements ExecutionRecoveryService {
  final DatabaseServiceImpl _databaseService;
  final WorkQueueService _workQueueService;
  final Uuid _uuid = const Uuid();

  ExecutionRecoveryServiceImpl({
    required DatabaseServiceImpl databaseService,
    required WorkQueueService workQueueService,
  })  : _databaseService = databaseService,
        _workQueueService = workQueueService;

  @override
  Future<RecoveryAssessment> assessTicket(String ticketId) async {
    final ticket = await _workQueueService.findTicketById(ticketId);
    if (ticket == null) {
      return const RecoveryAssessment(
        ticketId: '',
        eligibility: RecoveryEligibility.notEligible,
        summary: 'Ticket not found',
        suggestedActions: [],
        dryRunAvailable: false,
      );
    }
    if (!kRecoverableTicketStatuses.contains(ticket.status)) {
      return RecoveryAssessment(
        ticketId: ticketId,
        eligibility: RecoveryEligibility.notEligible,
        summary: 'Ticket status ${ticket.status.name} is not recoverable',
        suggestedActions: const [],
        dryRunAvailable: false,
      );
    }
    final actions = <String>['recovery_ticket_create'];
    if (ticket.status == WorkQueueTicketStatus.conflict) {
      actions.add('manual_review_required');
    }
    return RecoveryAssessment(
      ticketId: ticketId,
      eligibility: RecoveryEligibility.eligible,
      summary: 'Recovery available for ${ticket.requestedAction}',
      suggestedActions: actions,
      dryRunAvailable: true,
    );
  }

  @override
  Future<DryRunPreview> createRecoveryPreview(String ticketId) async {
    final ticket = await _workQueueService.findTicketById(ticketId);
    if (ticket == null) {
      throw StateError('Ticket not found: $ticketId');
    }
    final assessment = await assessTicket(ticketId);
    if (assessment.eligibility != RecoveryEligibility.eligible) {
      throw StateError(assessment.summary);
    }
    final summary = StringBuffer()
      ..writeln('recovery preview for ticket: $ticketId')
      ..writeln('source action: ${ticket.requestedAction}')
      ..writeln('source status: ${ticket.status.name}')
      ..writeln('target: ${ticket.targetPath ?? ticket.targetId ?? '-'}')
      ..writeln('policy: new recovery ticket, no direct re-execution');
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    final db = _databaseService.requireDatabase();
    await db.insert('ticket_dry_run_previews', {
      'id': id,
      'ticket_id': ticketId,
      'summary': summary.toString().trim(),
      'risk_level': DryRunRiskLevel.medium.name,
      'preview_status': DryRunPreviewStatus.ready.name,
      'created_at': now.toIso8601String(),
      'expires_at': now.add(const Duration(minutes: 30)).toIso8601String(),
    });
    return DryRunPreview(
      id: id,
      ticketId: ticketId,
      summary: summary.toString().trim(),
      riskLevel: DryRunRiskLevel.medium,
      previewStatus: DryRunPreviewStatus.ready,
      createdAt: now.toLocal(),
      expiresAt: now.add(const Duration(minutes: 30)).toLocal(),
    );
  }

  @override
  Future<WorkQueueTicket> createRecoveryTicket(String sourceTicketId) async {
    final source = await _workQueueService.findTicketById(sourceTicketId);
    if (source == null) {
      throw StateError('Source ticket not found: $sourceTicketId');
    }
    final assessment = await assessTicket(sourceTicketId);
    if (assessment.eligibility != RecoveryEligibility.eligible) {
      throw StateError(assessment.summary);
    }
    return _workQueueService.createTicket(
      CreateWorkQueueTicketInput(
        actor: 'user',
        requestedAction: 'recovery_${source.requestedAction}',
        targetType: source.targetType,
        targetId: source.targetId,
        targetPath: source.targetPath,
        permissionLevel: source.permissionLevel,
        baseRevision: source.baseRevision,
        permissionTokenId: source.permissionTokenId,
        payloadJson: source.payloadJson,
        reason: 'Recovery from $sourceTicketId',
        sourceTicketId: sourceTicketId,
        recoveryKind: 'execution_recovery',
      ),
    );
  }
}
