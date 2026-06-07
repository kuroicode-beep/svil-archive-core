// integrity_scan.dart — workspace 무결성 검사 도메인 모델

enum IntegrityScanRunStatus { running, completed, failed, cancelled }

enum IntegrityItemType {
  orphanMarkdown,
  staleDbRow,
  revisionMismatch,
  pathConflict,
  reportMismatch,
}

enum IntegrityItemSeverity { info, warning, important, critical }

enum IntegrityItemStatus { open, ticketCreated, ignored, resolved }

class IntegrityScanRun {
  final String id;
  final IntegrityScanRunStatus status;
  final int orphanCount;
  final int staleDbCount;
  final int conflictCount;
  final int warningCount;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? errorMessage;

  const IntegrityScanRun({
    required this.id,
    required this.status,
    required this.orphanCount,
    required this.staleDbCount,
    required this.conflictCount,
    required this.warningCount,
    required this.startedAt,
    this.completedAt,
    this.errorMessage,
  });
}

class IntegrityScanItem {
  final String id;
  final String scanRunId;
  final IntegrityItemType itemType;
  final String? targetPath;
  final String? documentId;
  final IntegrityItemSeverity severity;
  final IntegrityItemStatus status;
  final String reason;
  final DateTime createdAt;

  const IntegrityScanItem({
    required this.id,
    required this.scanRunId,
    required this.itemType,
    this.targetPath,
    this.documentId,
    required this.severity,
    required this.status,
    required this.reason,
    required this.createdAt,
  });
}

class IntegritySummary {
  final IntegrityScanRun? latestRun;
  final int openOrphanCount;
  final int openStaleDbCount;
  final int openConflictCount;
  final int openWarningCount;
  final bool hasOpenIssues;

  const IntegritySummary({
    this.latestRun,
    required this.openOrphanCount,
    required this.openStaleDbCount,
    required this.openConflictCount,
    required this.openWarningCount,
    required this.hasOpenIssues,
  });
}
