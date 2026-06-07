// ticket_execution.dart — ticket 실행 / dry-run / safe apply 도메인 모델

enum ExecutionResultStatus { success, failed, blocked, conflict, cancelled }

enum DryRunRiskLevel { low, medium, high, destructive }

enum DryRunPreviewStatus { ready, expired, consumed, failed }

class TicketExecutionLog {
  final String id;
  final String ticketId;
  final String action;
  final String? targetPath;
  final ExecutionResultStatus resultStatus;
  final String? errorCode;
  final String? errorMessage;
  final int? revisionBefore;
  final int? revisionAfter;
  final DateTime createdAt;

  const TicketExecutionLog({
    required this.id,
    required this.ticketId,
    required this.action,
    this.targetPath,
    required this.resultStatus,
    this.errorCode,
    this.errorMessage,
    this.revisionBefore,
    this.revisionAfter,
    required this.createdAt,
  });
}

class DryRunPreview {
  final String id;
  final String ticketId;
  final String summary;
  final DryRunRiskLevel riskLevel;
  final DryRunPreviewStatus previewStatus;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const DryRunPreview({
    required this.id,
    required this.ticketId,
    required this.summary,
    required this.riskLevel,
    required this.previewStatus,
    required this.createdAt,
    this.expiresAt,
  });
}

class TicketExecutionResult {
  final String ticketId;
  final ExecutionResultStatus status;
  final String? targetPath;
  final String? documentId;
  final int? revisionBefore;
  final int? revisionAfter;
  final String? errorCode;
  final String? errorMessage;

  const TicketExecutionResult({
    required this.ticketId,
    required this.status,
    this.targetPath,
    this.documentId,
    this.revisionBefore,
    this.revisionAfter,
    this.errorCode,
    this.errorMessage,
  });
}

class SafeApplyResult {
  final bool success;
  final String? documentId;
  final String? targetPath;
  final int? revisionBefore;
  final int? revisionAfter;
  final String? errorCode;
  final String? errorMessage;

  const SafeApplyResult({
    required this.success,
    this.documentId,
    this.targetPath,
    this.revisionBefore,
    this.revisionAfter,
    this.errorCode,
    this.errorMessage,
  });
}

class SafeCreateDocumentRequest {
  final String ticketId;
  final String actor;
  final String title;
  final String relativeDir;
  final String? type;
  final String initialContent;
  final String? permissionTokenId;

  const SafeCreateDocumentRequest({
    required this.ticketId,
    required this.actor,
    required this.title,
    required this.relativeDir,
    this.type,
    this.initialContent = '',
    this.permissionTokenId,
  });
}

class SafeUpdateDocumentRequest {
  final String ticketId;
  final String actor;
  final String documentId;
  final int baseRevision;
  final String? title;
  final String? content;
  final String? permissionTokenId;

  const SafeUpdateDocumentRequest({
    required this.ticketId,
    required this.actor,
    required this.documentId,
    required this.baseRevision,
    this.title,
    this.content,
    this.permissionTokenId,
  });
}

class SafeTrashDocumentRequest {
  final String ticketId;
  final String actor;
  final String documentId;
  final String? permissionTokenId;

  const SafeTrashDocumentRequest({
    required this.ticketId,
    required this.actor,
    required this.documentId,
    this.permissionTokenId,
  });
}

class QueueExecutionSummary {
  final int approvedReadyCount;
  final int executionFailedCount;
  final int conflictCount;
  final int completedCount;

  const QueueExecutionSummary({
    required this.approvedReadyCount,
    required this.executionFailedCount,
    required this.conflictCount,
    required this.completedCount,
  });
}
