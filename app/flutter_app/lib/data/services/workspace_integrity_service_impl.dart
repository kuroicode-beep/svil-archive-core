// workspace_integrity_service_impl.dart — workspace 무결성 검사 구현

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/integrity_scan.dart';
import '../../domain/services/report_consistency_service.dart';
import '../../domain/services/workspace_file_inventory_service.dart';
import '../../domain/services/workspace_integrity_service.dart';
import '../db/database_service_impl.dart';
import '../platform/path_adapter.dart';

class WorkspaceIntegrityServiceImpl implements WorkspaceIntegrityService {
  final DatabaseServiceImpl _databaseService;
  final WorkspaceFileInventoryService _inventoryService;
  final ReportConsistencyService _reportConsistencyService;
  final String workspaceId;
  final Uuid _uuid = const Uuid();

  WorkspaceIntegrityServiceImpl({
    required DatabaseServiceImpl databaseService,
    required WorkspaceFileInventoryService inventoryService,
    required ReportConsistencyService reportConsistencyService,
    required this.workspaceId,
  })  : _databaseService = databaseService,
        _inventoryService = inventoryService,
        _reportConsistencyService = reportConsistencyService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<IntegrityScanRun> runScan() async {
    final runId = _uuid.v4();
    final startedAt = DateTime.now().toUtc().toIso8601String();
    await _db.insert('integrity_scan_runs', {
      'id': runId,
      'status': IntegrityScanRunStatus.running.name,
      'orphan_count': 0,
      'stale_db_count': 0,
      'conflict_count': 0,
      'warning_count': 0,
      'started_at': startedAt,
    });

    try {
      final filePaths = await _inventoryService.listWorkspaceMarkdownPaths();
      final fileSet = filePaths.toSet();
      final dbRows = await _db.query(
        'documents',
        where: 'workspace_id = ?',
        whereArgs: [workspaceId],
      );
      final dbPathMap = <String, Map<String, Object?>>{};
      for (final row in dbRows) {
        final path = row['relative_path'] as String;
        dbPathMap[path] = row;
      }
      final dbPathSet = dbPathMap.keys.toSet();

      int orphanCount = 0;
      int staleCount = 0;
      int conflictCount = 0;
      int warningCount = 0;

      for (final path in fileSet.difference(dbPathSet)) {
        await _insertItem(
          runId: runId,
          itemType: IntegrityItemType.orphanMarkdown,
          targetPath: path,
          severity: IntegrityItemSeverity.important,
          reason: 'Markdown file exists without DB row',
        );
        orphanCount++;
      }

      for (final path in dbPathSet.difference(fileSet)) {
        final row = dbPathMap[path]!;
        final isDeleted = (row['is_deleted'] as int? ?? 0) == 1;
        if (isDeleted) continue;
        await _insertItem(
          runId: runId,
          itemType: IntegrityItemType.staleDbRow,
          targetPath: path,
          documentId: row['id'] as String?,
          severity: IntegrityItemSeverity.important,
          reason: 'DB row exists but Markdown file is missing',
        );
        staleCount++;
      }

      for (final path in fileSet.intersection(dbPathSet)) {
        final row = dbPathMap[path]!;
        final dbCategory = row['category'] as String?;
        String pathCategory;
        try {
          pathCategory = categoryPathFromRelativePath(path);
        } catch (_) {
          continue;
        }
        if (dbCategory != null && dbCategory != pathCategory) {
          await _insertItem(
            runId: runId,
            itemType: IntegrityItemType.pathConflict,
            targetPath: path,
            documentId: row['id'] as String?,
            severity: IntegrityItemSeverity.warning,
            reason: 'Category mismatch: db=$dbCategory path=$pathCategory',
          );
          warningCount++;
        }
      }

      final conflictRows = await _db.rawQuery(
        "SELECT COUNT(*) AS c FROM sync_state WHERE conflict = 1 OR status = 'conflict'",
      );
      conflictCount = conflictRows.first['c'] as int? ?? 0;
      if (conflictCount > 0) {
        await _insertItem(
          runId: runId,
          itemType: IntegrityItemType.revisionMismatch,
          severity: IntegrityItemSeverity.critical,
          reason: 'sync_state conflict count: $conflictCount',
        );
      }

      final report = await _reportConsistencyService.checkReports();
      for (final mismatch in report.mismatches) {
        await _insertItem(
          runId: runId,
          itemType: IntegrityItemType.reportMismatch,
          severity: IntegrityItemSeverity.warning,
          reason:
              '${mismatch.sprintLabel}: expected ${mismatch.expectedCommit}, actual ${mismatch.actualCommit ?? '-'}',
        );
        warningCount++;
      }

      final completedAt = DateTime.now().toUtc().toIso8601String();
      await _db.update(
        'integrity_scan_runs',
        {
          'status': IntegrityScanRunStatus.completed.name,
          'orphan_count': orphanCount,
          'stale_db_count': staleCount,
          'conflict_count': conflictCount,
          'warning_count': warningCount,
          'completed_at': completedAt,
        },
        where: 'id = ?',
        whereArgs: [runId],
      );

      return IntegrityScanRun(
        id: runId,
        status: IntegrityScanRunStatus.completed,
        orphanCount: orphanCount,
        staleDbCount: staleCount,
        conflictCount: conflictCount,
        warningCount: warningCount,
        startedAt: DateTime.parse(startedAt).toLocal(),
        completedAt: DateTime.parse(completedAt).toLocal(),
      );
    } catch (e) {
      await _db.update(
        'integrity_scan_runs',
        {
          'status': IntegrityScanRunStatus.failed.name,
          'error_message': e.toString(),
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [runId],
      );
      rethrow;
    }
  }

  @override
  Future<IntegritySummary> getLatestSummary() async {
    final runs = await _db.query(
      'integrity_scan_runs',
      orderBy: 'started_at DESC',
      limit: 1,
    );
    IntegrityScanRun? latest;
    if (runs.isNotEmpty) {
      latest = _mapRun(runs.first);
    }

    Future<int> openCount(String type) async {
      return Sqflite.firstIntValue(
            await _db.rawQuery(
              "SELECT COUNT(*) FROM integrity_scan_items WHERE status = 'open' AND item_type = ?",
              [type],
            ),
          ) ??
          0;
    }

    final openOrphan = await openCount(IntegrityItemType.orphanMarkdown.name);
    final openStale = await openCount(IntegrityItemType.staleDbRow.name);
    final openConflict = await openCount(IntegrityItemType.revisionMismatch.name);
    final openWarning = Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM integrity_scan_items WHERE status = 'open' AND severity IN ('warning', 'important')",
          ),
        ) ??
        0;

    return IntegritySummary(
      latestRun: latest,
      openOrphanCount: openOrphan,
      openStaleDbCount: openStale,
      openConflictCount: openConflict,
      openWarningCount: openWarning,
      hasOpenIssues: openOrphan + openStale + openConflict + openWarning > 0,
    );
  }

  @override
  Future<List<IntegrityScanItem>> listOpenItems() async {
    final rows = await _db.query(
      'integrity_scan_items',
      where: "status = 'open'",
      orderBy: 'created_at DESC',
    );
    return rows.map(_mapItem).toList();
  }

  @override
  Future<void> updateItemStatus(String itemId, IntegrityItemStatus status) async {
    await _db.update(
      'integrity_scan_items',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  /// scan item row를 삽입한다.
  Future<void> _insertItem({
    required String runId,
    required IntegrityItemType itemType,
    String? targetPath,
    String? documentId,
    required IntegrityItemSeverity severity,
    required String reason,
  }) async {
    await _db.insert('integrity_scan_items', {
      'id': _uuid.v4(),
      'scan_run_id': runId,
      'item_type': itemType.name,
      'target_path': targetPath,
      'document_id': documentId,
      'severity': severity.name,
      'status': IntegrityItemStatus.open.name,
      'reason': reason,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// scan run row를 변환한다.
  IntegrityScanRun _mapRun(Map<String, Object?> row) {
    return IntegrityScanRun(
      id: row['id'] as String,
      status: IntegrityScanRunStatus.values.firstWhere(
        (s) => s.name == (row['status'] as String? ?? 'failed'),
        orElse: () => IntegrityScanRunStatus.failed,
      ),
      orphanCount: row['orphan_count'] as int? ?? 0,
      staleDbCount: row['stale_db_count'] as int? ?? 0,
      conflictCount: row['conflict_count'] as int? ?? 0,
      warningCount: row['warning_count'] as int? ?? 0,
      startedAt: DateTime.parse(row['started_at'] as String).toLocal(),
      completedAt: row['completed_at'] != null
          ? DateTime.parse(row['completed_at'] as String).toLocal()
          : null,
      errorMessage: row['error_message'] as String?,
    );
  }

  /// scan item row를 변환한다.
  IntegrityScanItem _mapItem(Map<String, Object?> row) {
    return IntegrityScanItem(
      id: row['id'] as String,
      scanRunId: row['scan_run_id'] as String,
      itemType: IntegrityItemType.values.firstWhere(
        (t) => t.name == (row['item_type'] as String? ?? 'orphanMarkdown'),
        orElse: () => IntegrityItemType.orphanMarkdown,
      ),
      targetPath: row['target_path'] as String?,
      documentId: row['document_id'] as String?,
      severity: IntegrityItemSeverity.values.firstWhere(
        (s) => s.name == (row['severity'] as String? ?? 'warning'),
        orElse: () => IntegrityItemSeverity.warning,
      ),
      status: IntegrityItemStatus.values.firstWhere(
        (s) => s.name == (row['status'] as String? ?? 'open'),
        orElse: () => IntegrityItemStatus.open,
      ),
      reason: row['reason'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}
