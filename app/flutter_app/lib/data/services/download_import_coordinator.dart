// download_import_coordinator.dart — Import Queue 항목을 Sprint 15 정식 등록 흐름으로 import (Sprint 16)

import 'package:path/path.dart' as p;

import '../../domain/models/document_import.dart';
import '../../domain/models/import_queue_item.dart';
import '../../domain/services/document_import_service.dart';
import '../../domain/services/import_queue_service.dart';

/// Import Queue 항목 import 결과.
class QueueImportOutcome {
  final ImportQueueItem item;
  final ImportExecutionResult? result;
  final ImportQueueStatus status;
  final String? message;

  const QueueImportOutcome({
    required this.item,
    required this.result,
    required this.status,
    this.message,
  });
}

class DownloadImportCoordinator {
  final ImportQueueService _queueService;
  final DocumentImportService _importService;

  DownloadImportCoordinator({
    required ImportQueueService queueService,
    required DocumentImportService importService,
  })  : _queueService = queueService,
        _importService = importService;

  /// 단일 큐 항목을 dry-run → approved snapshot → executeApprovedImport 순으로 등록한다.
  /// 기존 executeImport(dryRunOnly:false) 우회 없이 Sprint 15 흐름을 재사용한다.
  Future<QueueImportOutcome> importItem(
    String id, {
    bool writeFrontmatter = false,
  }) async {
    final item = await _queueService.findById(id);
    if (item == null) {
      throw StateError('Import queue item not found: $id');
    }

    final sourcePath = p.normalize(item.sourceAbsolutePath);
    final options = DocumentImportOptions(
      absolutePaths: [sourcePath],
      includeSubfolders: false,
      writeFrontmatter: writeFrontmatter,
      dryRunOnly: true,
      targetFileNameOverrides: {sourcePath: item.targetFileName},
    );

    final preview = await _importService.scanPaths([sourcePath], options);
    final hasConflict = preview.candidates.any(
      (c) =>
          c.status == ImportCandidateStatus.conflictTargetPath ||
          c.status == ImportCandidateStatus.conflictSacId,
    );
    if (hasConflict) {
      await _queueService.updateStatus(
        id,
        ImportQueueStatus.conflict,
        errorMessage: '대상 파일명 또는 sac_id 충돌 — 자동 덮어쓰기 차단',
      );
      final updated = await _queueService.findById(id);
      return QueueImportOutcome(
        item: updated ?? item,
        result: null,
        status: ImportQueueStatus.conflict,
        message: '충돌로 import 중단',
      );
    }

    final importable = preview.candidates.where((c) => c.isImportable).toList();
    if (importable.isEmpty) {
      await _queueService.updateStatus(
        id,
        ImportQueueStatus.skipped,
        errorMessage: '등록 대상 후보 없음 (이미 등록되었거나 무효)',
      );
      final updated = await _queueService.findById(id);
      return QueueImportOutcome(
        item: updated ?? item,
        result: null,
        status: ImportQueueStatus.skipped,
        message: '등록 대상 없음',
      );
    }

    final snapshot = ImportApprovedSnapshot(
      options: options.copyWith(dryRunOnly: false),
      preview: preview,
    );

    try {
      final result = await _importService.executeApprovedImport(snapshot);
      final docId =
          result.registeredDocumentIds.isNotEmpty ? result.registeredDocumentIds.first : null;
      final status = result.registeredCount > 0
          ? ImportQueueStatus.imported
          : ImportQueueStatus.failed;
      await _queueService.updateStatus(
        id,
        status,
        importedDocumentId: docId,
        errorMessage: result.failures.isNotEmpty ? result.failures.join('; ') : null,
      );
      final updated = await _queueService.findById(id);
      return QueueImportOutcome(
        item: updated ?? item,
        result: result,
        status: status,
        message: status == ImportQueueStatus.imported ? '등록 완료' : '등록 실패',
      );
    } catch (e) {
      await _queueService.updateStatus(
        id,
        ImportQueueStatus.failed,
        errorMessage: e.toString(),
      );
      final updated = await _queueService.findById(id);
      return QueueImportOutcome(
        item: updated ?? item,
        result: null,
        status: ImportQueueStatus.failed,
        message: 'import 예외: $e',
      );
    }
  }
}
