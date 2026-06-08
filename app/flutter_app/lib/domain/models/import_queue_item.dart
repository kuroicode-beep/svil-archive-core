// import_queue_item.dart — 다운로드 감시 Import Queue 항목 (Sprint 16)

/// Import Queue 항목 상태.
enum ImportQueueStatus {
  detected,
  pending,
  imported,
  failed,
  skipped,
  conflict,
}

/// 상태 문자열 변환.
String importQueueStatusToString(ImportQueueStatus status) => status.name;

/// 문자열을 상태로 변환한다 (알 수 없으면 detected).
ImportQueueStatus importQueueStatusFromString(String value) {
  return ImportQueueStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => ImportQueueStatus.detected,
  );
}

/// 다운로드 감시로 등록된 Import 대기 항목.
class ImportQueueItem {
  final String id;
  final String originalFileName;
  final String sourceAbsolutePath;
  final String? matchedPrefix;
  final String targetFileName;
  final String sourceAi;
  final int fileSize;
  final ImportQueueStatus status;
  final DateTime detectedAt;
  final DateTime updatedAt;
  final String? importedDocumentId;
  final String? errorMessage;

  const ImportQueueItem({
    required this.id,
    required this.originalFileName,
    required this.sourceAbsolutePath,
    required this.matchedPrefix,
    required this.targetFileName,
    required this.sourceAi,
    required this.fileSize,
    required this.status,
    required this.detectedAt,
    required this.updatedAt,
    this.importedDocumentId,
    this.errorMessage,
  });

  /// SQLite row로부터 항목을 생성한다.
  factory ImportQueueItem.fromRow(Map<String, Object?> row) {
    return ImportQueueItem(
      id: row['id'] as String,
      originalFileName: row['original_file_name'] as String,
      sourceAbsolutePath: row['source_absolute_path'] as String,
      matchedPrefix: row['matched_prefix'] as String?,
      targetFileName: row['target_file_name'] as String,
      sourceAi: row['source_ai'] as String,
      fileSize: (row['file_size'] as int?) ?? 0,
      status: importQueueStatusFromString(row['status'] as String? ?? 'detected'),
      detectedAt: DateTime.parse(row['detected_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      importedDocumentId: row['imported_document_id'] as String?,
      errorMessage: row['error_message'] as String?,
    );
  }
}
