// work_queue.dart — 작업큐 / MCP / conflict guard 도메인 모델

enum PermissionLevel { read, write, destructive, personal, admin }

enum WorkQueueTicketStatus {
  pending,
  approved,
  running,
  completed,
  blocked,
  conflict,
  rejected,
  failed,
  cancelled,
}

enum ConflictGuardAction { allow, block, conflict, requireApproval }

class WorkQueueTicket {
  final String id;
  final String actor;
  final String requestedAction;
  final String targetType;
  final String? targetId;
  final String? targetPath;
  final PermissionLevel permissionLevel;
  final WorkQueueTicketStatus status;
  final int priority;
  final String? reason;
  final String? errorMessage;
  final int? baseRevision;
  final String? permissionTokenId;
  final String? payloadJson;
  final String? sourceTicketId;
  final String? recoveryKind;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkQueueTicket({
    required this.id,
    required this.actor,
    required this.requestedAction,
    required this.targetType,
    this.targetId,
    this.targetPath,
    required this.permissionLevel,
    required this.status,
    this.priority = 5,
    this.reason,
    this.errorMessage,
    this.baseRevision,
    this.permissionTokenId,
    this.payloadJson,
    this.sourceTicketId,
    this.recoveryKind,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 복구 티켓 여부를 반환한다.
  bool get isRecoveryTicket =>
      recoveryKind != null && recoveryKind!.isNotEmpty;
}

class CreateWorkQueueTicketInput {
  final String actor;
  final String requestedAction;
  final String targetType;
  final String? targetId;
  final String? targetPath;
  final PermissionLevel permissionLevel;
  final int priority;
  final String? reason;
  final int? baseRevision;
  final String? permissionTokenId;
  final String? payloadJson;
  final String? sourceTicketId;
  final String? recoveryKind;

  const CreateWorkQueueTicketInput({
    required this.actor,
    required this.requestedAction,
    required this.targetType,
    this.targetId,
    this.targetPath,
    required this.permissionLevel,
    this.priority = 5,
    this.reason,
    this.baseRevision,
    this.permissionTokenId,
    this.payloadJson,
    this.sourceTicketId,
    this.recoveryKind,
  });
}

class WorkQueueSummary {
  final int pendingCount;
  final int conflictCount;
  final int failedCount;
  final int blockedCount;
  final int approvedCount;
  final int runningCount;
  final int completedCount;

  const WorkQueueSummary({
    required this.pendingCount,
    required this.conflictCount,
    required this.failedCount,
    required this.blockedCount,
    required this.approvedCount,
    required this.runningCount,
    required this.completedCount,
  });
}

class DocumentWriteRequest {
  final String? documentId;
  final String? relativePath;
  final int? baseRevision;
  final String actor;

  const DocumentWriteRequest({
    this.documentId,
    this.relativePath,
    this.baseRevision,
    required this.actor,
  });
}

class DestructiveRequest {
  final String? documentId;
  final String? relativePath;
  final String actor;
  final String action;

  const DestructiveRequest({
    this.documentId,
    this.relativePath,
    required this.actor,
    required this.action,
  });
}

class ConflictGuardResult {
  final ConflictGuardAction action;
  final String message;

  const ConflictGuardResult({
    required this.action,
    required this.message,
  });
}

enum McpBridgeConnectionState { offline, localReady, error }

class McpBridgeStatus {
  final McpBridgeConnectionState state;
  final String label;
  final bool localOnly;
  final bool remoteExposureEnabled;

  const McpBridgeStatus({
    required this.state,
    required this.label,
    this.localOnly = true,
    this.remoteExposureEnabled = false,
  });
}

class McpToolSetting {
  final String toolName;
  final bool enabled;
  final PermissionLevel permissionLevel;
  final String description;
  final DateTime updatedAt;

  const McpToolSetting({
    required this.toolName,
    required this.enabled,
    required this.permissionLevel,
    required this.description,
    required this.updatedAt,
  });
}

class McpToolRequest {
  final String toolName;
  final String actor;
  final String? targetType;
  final String? targetId;
  final String? targetPath;
  final int? baseRevision;
  final String? permissionTokenId;

  const McpToolRequest({
    required this.toolName,
    required this.actor,
    this.targetType,
    this.targetId,
    this.targetPath,
    this.baseRevision,
    this.permissionTokenId,
  });
}

class PermissionTokenRecord {
  final String id;
  final PermissionLevel tokenType;
  final String actor;
  final String scope;
  final String status;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const PermissionTokenRecord({
    required this.id,
    required this.tokenType,
    required this.actor,
    required this.scope,
    required this.status,
    this.expiresAt,
    required this.createdAt,
  });
}

class McpPrivacySummary {
  final bool localOnly;
  final bool remoteMcpEnabled;
  final int writeTokenCount;
  final int destructiveTokenCount;
  final int personalTokenCount;
  final int enabledToolCount;
  final int disabledToolCount;

  const McpPrivacySummary({
    required this.localOnly,
    required this.remoteMcpEnabled,
    required this.writeTokenCount,
    required this.destructiveTokenCount,
    required this.personalTokenCount,
    required this.enabledToolCount,
    required this.disabledToolCount,
  });
}
