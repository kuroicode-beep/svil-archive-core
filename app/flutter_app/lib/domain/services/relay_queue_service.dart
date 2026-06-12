// relay_queue_service.dart — Relay Queue 서비스 인터페이스

import '../models/relay_queue_item.dart';

/// import_queue와 분리된 에이전트 작업 큐.
abstract class RelayQueueService {
  /// relay 작업을 pending으로 등록한다.
  Future<RelayQueueItem> enqueueTask({
    String? sourceImportQueueId,
    String? sourceDocumentId,
    required String targetAgent,
    String? eventType,
    String? project,
    int priority,
    String? notice,
  });

  /// 상태를 갱신한다 (sync_journal 연동은 impl에서 수행).
  Future<void> updateStatus(
    String id,
    RelayQueueStatus status, {
    String? resultDocumentId,
    String? errorMessage,
  });

  /// 항목 목록을 반환한다.
  Future<List<RelayQueueItem>> listItems({List<RelayQueueStatus>? statuses});

  /// id로 항목을 조회한다.
  Future<RelayQueueItem?> findById(String id);
}
