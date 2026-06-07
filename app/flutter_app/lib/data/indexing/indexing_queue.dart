// indexing_queue.dart — debounce/batch 문서 인덱싱 큐

import 'dart:async';

import 'document_indexer.dart';

const Duration kIndexingDebounce = Duration(milliseconds: 500);
const Duration kIndexingBatchWindow = Duration(seconds: 2);

class IndexingQueueStatus {
  final int pendingCount;
  final bool isProcessing;

  const IndexingQueueStatus({
    required this.pendingCount,
    required this.isProcessing,
  });
}

class IndexingQueue {
  final DocumentIndexer _indexer;
  final Duration debounce;
  final Duration batchWindow;

  final Set<String> _pending = {};
  final Map<String, Timer> _debounceTimers = {};
  Timer? _batchTimer;
  bool _processing = false;

  IndexingQueue({
    required DocumentIndexer indexer,
    this.debounce = kIndexingDebounce,
    this.batchWindow = kIndexingBatchWindow,
  }) : _indexer = indexer;

  /// 문서 인덱싱을 큐에 등록한다.
  void queueDocument(String documentId) {
    _pending.add(documentId);
    _debounceTimers[documentId]?.cancel();
    _debounceTimers[documentId] = Timer(debounce, () {
      _debounceTimers.remove(documentId);
      _scheduleBatch();
    });
  }

  /// 여러 문서 인덱싱을 큐에 등록한다.
  void queueDocuments(Iterable<String> documentIds) {
    for (final id in documentIds) {
      queueDocument(id);
    }
  }

  /// 즉시 단일 문서를 재인덱싱한다.
  Future<void> reindexDocument(String documentId) async {
    try {
      await _indexer.reindexDocument(documentId);
    } catch (_) {
      // indexing failure는 문서 저장 실패로 전파하지 않음
    }
  }

  /// workspace 전체 재인덱싱을 수행한다.
  Future<void> reindexWorkspace() => _indexer.reindexWorkspace();

  /// 큐 상태를 반환한다.
  IndexingQueueStatus getQueueStatus() {
    return IndexingQueueStatus(
      pendingCount: _pending.length,
      isProcessing: _processing,
    );
  }

  /// batch 처리를 예약한다.
  void _scheduleBatch() {
    if (_batchTimer != null) return;
    _batchTimer = Timer(batchWindow, () async {
      _batchTimer = null;
      await _processBatch();
    });
  }

  /// pending 문서들을 batch 인덱싱한다.
  Future<void> _processBatch() async {
    if (_pending.isEmpty || _processing) return;
    _processing = true;
    final ids = _pending.toList();
    _pending.clear();
    for (final id in ids) {
      await reindexDocument(id);
    }
    _processing = false;
    if (_pending.isNotEmpty) {
      _scheduleBatch();
    }
  }

  /// 테스트용 — debounce/batch를 즉시 flush한다.
  Future<void> flushForTest() async {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _batchTimer?.cancel();
    _batchTimer = null;
    await _processBatch();
  }

  /// 타이머를 정리한다.
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _batchTimer?.cancel();
    _batchTimer = null;
    _pending.clear();
  }
}
