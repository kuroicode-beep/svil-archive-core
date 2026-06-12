// relay_queue_item.dart — Relay Queue 항목 (import_queue와 분리)

/// relay_queue 상태값.
enum RelayQueueStatus {
  pending,
  running,
  done,
  failed,
  blocked,
  cancelled;

  static RelayQueueStatus? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in RelayQueueStatus.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

/// relay_queue 테이블 row 모델.
class RelayQueueItem {
  final String id;
  final String? sourceImportQueueId;
  final String? sourceDocumentId;
  final String targetAgent;
  final String? eventType;
  final String? project;
  final int priority;
  final RelayQueueStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? resultDocumentId;
  final String? errorMessage;
  final String? notice;

  const RelayQueueItem({
    required this.id,
    this.sourceImportQueueId,
    this.sourceDocumentId,
    required this.targetAgent,
    this.eventType,
    this.project,
    this.priority = 5,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.startedAt,
    this.completedAt,
    this.resultDocumentId,
    this.errorMessage,
    this.notice,
  });

  /// DB row를 RelayQueueItem으로 변환한다.
  factory RelayQueueItem.fromRow(Map<String, Object?> row) {
    return RelayQueueItem(
      id: row['id'] as String,
      sourceImportQueueId: row['source_import_queue_id'] as String?,
      sourceDocumentId: row['source_document_id'] as String?,
      targetAgent: row['target_agent'] as String? ?? 'unknown',
      eventType: row['event_type'] as String?,
      project: row['project'] as String?,
      priority: (row['priority'] as int?) ?? 5,
      status: RelayQueueStatus.tryParse(row['status'] as String?) ??
          RelayQueueStatus.pending,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      startedAt: row['started_at'] != null
          ? DateTime.parse(row['started_at'] as String).toLocal()
          : null,
      completedAt: row['completed_at'] != null
          ? DateTime.parse(row['completed_at'] as String).toLocal()
          : null,
      resultDocumentId: row['result_document_id'] as String?,
      errorMessage: row['error_message'] as String?,
      notice: row['notice'] as String?,
    );
  }
}
