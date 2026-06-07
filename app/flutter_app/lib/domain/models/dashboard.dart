// dashboard.dart — 대시보드 / 개인정보 / 로컬 AI 요약 모델

import 'work_queue.dart';

class AiCollaborationSummary {
  final int activeWorkInstructions;
  final int handoffPending;
  final int verificationNeeded;
  final int criticalIssues;
  final String lastCompletedSprint;

  const AiCollaborationSummary({
    required this.activeWorkInstructions,
    required this.handoffPending,
    required this.verificationNeeded,
    required this.criticalIssues,
    required this.lastCompletedSprint,
  });
}

class CriticalAlertSummary {
  final int syncConflictCount;
  final int pendingExtractionCount;
  final int privacyWarningCount;
  final int failedIndexingCount;

  const CriticalAlertSummary({
    required this.syncConflictCount,
    required this.pendingExtractionCount,
    required this.privacyWarningCount,
    required this.failedIndexingCount,
  });

  bool get hasCritical =>
      syncConflictCount > 0 ||
      pendingExtractionCount > 0 ||
      privacyWarningCount > 0 ||
      failedIndexingCount > 0;
}

class RecentActivityItem {
  final String id;
  final String action;
  final String targetType;
  final String? targetId;
  final DateTime occurredAt;

  const RecentActivityItem({
    required this.id,
    required this.action,
    required this.targetType,
    this.targetId,
    required this.occurredAt,
  });
}

class DashboardSummary {
  final AiCollaborationSummary aiCollaboration;
  final CriticalAlertSummary criticalAlerts;
  final int personalArchiveItemCount;
  final int approvedPersonalItemCount;
  final List<String> recentTags;
  final List<RecentActivityItem> recentActivities;
  final int documentCount;
  final int trashCount;
  final McpBridgeStatus mcpBridgeStatus;
  final WorkQueueSummary workQueueSummary;
  final int enabledMcpToolCount;
  final int disabledMcpToolCount;
  final List<RecentActivityItem> recentWorkQueueActivities;

  const DashboardSummary({
    required this.aiCollaboration,
    required this.criticalAlerts,
    required this.personalArchiveItemCount,
    required this.approvedPersonalItemCount,
    required this.recentTags,
    required this.recentActivities,
    required this.documentCount,
    required this.trashCount,
    required this.mcpBridgeStatus,
    required this.workQueueSummary,
    required this.enabledMcpToolCount,
    required this.disabledMcpToolCount,
    required this.recentWorkQueueActivities,
  });
}

class PrivacySummary {
  final bool localProcessingEnabled;
  final bool externalTransferEnabled;
  final int pendingCandidateCount;
  final int rejectedCandidateCount;
  final int activePersonalItemCount;
  final int deletedPersonalItemCount;
  final List<RecentActivityItem> recentPrivacyAuditLogs;
  final String exportPolicyLabel;
  final McpPrivacySummary mcpPrivacy;

  const PrivacySummary({
    required this.localProcessingEnabled,
    required this.externalTransferEnabled,
    required this.pendingCandidateCount,
    required this.rejectedCandidateCount,
    required this.activePersonalItemCount,
    required this.deletedPersonalItemCount,
    required this.recentPrivacyAuditLogs,
    required this.exportPolicyLabel,
    required this.mcpPrivacy,
  });
}

enum LocalAiConnectionState { offline, connected, error }

class LocalAiStatus {
  final LocalAiConnectionState state;
  final String label;
  final String? endpoint;

  const LocalAiStatus({
    required this.state,
    required this.label,
    this.endpoint,
  });
}

class LocalAiModel {
  final String name;
  final String? family;

  const LocalAiModel({required this.name, this.family});
}

class LlmSelfInfoExportResult {
  final String relativePath;
  final String absolutePath;
  final String previewMarkdown;
  final int includedItemCount;
  final int excludedPendingCount;
  final int excludedRejectedCount;
  final int excludedDeletedCount;

  const LlmSelfInfoExportResult({
    required this.relativePath,
    required this.absolutePath,
    required this.previewMarkdown,
    required this.includedItemCount,
    required this.excludedPendingCount,
    required this.excludedRejectedCount,
    required this.excludedDeletedCount,
  });
}
