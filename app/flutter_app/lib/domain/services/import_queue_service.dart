// import_queue_service.dart — Import Queue 서비스 인터페이스 (Sprint 16)

import '../models/import_queue_item.dart';

abstract class ImportQueueService {
  /// 감지된 다운로드 파일을 큐에 등록한다. 이미 등록된 경로면 null을 반환한다.
  Future<ImportQueueItem?> enqueueDetected({
    required String sourceAbsolutePath,
    required String originalFileName,
    required String? matchedPrefix,
    required String targetFileName,
    required String sourceAi,
    required int fileSize,
  });

  /// 큐 항목 목록을 조회한다 (상태 필터 옵션).
  Future<List<ImportQueueItem>> listItems({List<ImportQueueStatus>? statuses});

  /// 단일 항목을 조회한다.
  Future<ImportQueueItem?> findById(String id);

  /// 큐 항목 상태를 변경한다.
  Future<void> updateStatus(
    String id,
    ImportQueueStatus status, {
    String? importedDocumentId,
    String? errorMessage,
  });

  /// 상태별 개수를 반환한다.
  Future<int> countByStatus(ImportQueueStatus status);

  /// 큐 항목을 제거한다.
  Future<void> removeItem(String id);
}
