// dashboard_service_impl.dart — 대시보드 요약 SQLite 구현

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/dashboard.dart';
import '../../domain/models/work_queue.dart';
import '../../domain/services/dashboard_service.dart';
import '../../domain/services/mcp_bridge_status_service.dart';
import '../../domain/services/mcp_tool_registry_service.dart';
import '../../domain/services/queue_execution_service.dart';
import '../../domain/models/rc_finalization.dart';
import '../../domain/services/release_finalization_export_service.dart';
import '../../domain/services/release_readiness_service.dart';
import '../../domain/services/report_consistency_service.dart';
import '../../domain/services/smoke_test_record_service.dart';
import '../../domain/services/work_queue_service.dart';
import '../../domain/services/workspace_integrity_service.dart';
import '../db/database_service_impl.dart';

class DashboardServiceImpl implements DashboardService {
  final DatabaseServiceImpl _databaseService;
  final WorkQueueService _workQueueService;
  final McpBridgeStatusService _mcpBridgeService;
  final McpToolRegistryService _toolRegistryService;
  final QueueExecutionService _queueExecutionService;
  final WorkspaceIntegrityService _integrityService;
  final ReportConsistencyService _reportConsistencyService;
  final SmokeTestRecordService _smokeTestRecordService;
  final ReleaseReadinessService _releaseReadinessService;
  final ReleaseFinalizationExportService _releaseFinalizationExportService;

  DashboardServiceImpl({
    required DatabaseServiceImpl databaseService,
    required WorkQueueService workQueueService,
    required McpBridgeStatusService mcpBridgeService,
    required McpToolRegistryService toolRegistryService,
    required QueueExecutionService queueExecutionService,
    required WorkspaceIntegrityService integrityService,
    required ReportConsistencyService reportConsistencyService,
    required SmokeTestRecordService smokeTestRecordService,
    required ReleaseReadinessService releaseReadinessService,
    required ReleaseFinalizationExportService releaseFinalizationExportService,
  })  : _databaseService = databaseService,
        _workQueueService = workQueueService,
        _mcpBridgeService = mcpBridgeService,
        _toolRegistryService = toolRegistryService,
        _queueExecutionService = queueExecutionService,
        _integrityService = integrityService,
        _reportConsistencyService = reportConsistencyService,
        _smokeTestRecordService = smokeTestRecordService,
        _releaseReadinessService = releaseReadinessService,
        _releaseFinalizationExportService = releaseFinalizationExportService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<DashboardSummary> getDashboardSummary() async {
    final critical = await _buildCriticalAlerts();
    final personalCounts = await _countPersonalArchive();
    final recentTags = await _collectRecentTags();
    final recentActivities = await _loadRecentActivities();
    final documentCount = Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM documents WHERE is_deleted = 0'),
        ) ??
        0;
    final trashCount = Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM trash_items'),
        ) ??
        0;

    final mcpStatus = await _mcpBridgeService.checkStatus();
    final queueSummary = await _workQueueService.getSummary();
    final tools = await _toolRegistryService.listTools();
    final enabledCount = tools.where((t) => t.enabled).length;
    final queueActivities = await _loadWorkQueueActivities();
    final executionSummary = await _queueExecutionService.getExecutionSummary();
    final integritySummary = await _integrityService.getLatestSummary();
    final report = await _reportConsistencyService.checkReports();
    final macSmoke = await _smokeTestRecordService.getLatestForPlatform('macOS');
    final winSmoke = await _smokeTestRecordService.getLatestForPlatform('Windows');
    final releaseReadiness = await _releaseReadinessService.evaluate();
    final exportStatus = await _releaseFinalizationExportService.getExportStatus();
    final rcFinalization = RcFinalizationSummary(
      status: releaseReadiness.rcFinalizationStatus,
      statusLabel: releaseReadiness.rcStatusLabel,
      readiness: releaseReadiness,
      exportStatus: exportStatus,
      macSmokeStatus: macSmoke?.status,
      windowsSmokeStatus: winSmoke?.status,
    );

    return DashboardSummary(
      aiCollaboration: _buildAiCollaborationSummary(critical, queueSummary),
      criticalAlerts: critical,
      personalArchiveItemCount: personalCounts.$1,
      approvedPersonalItemCount: personalCounts.$2,
      recentTags: recentTags,
      recentActivities: recentActivities,
      documentCount: documentCount,
      trashCount: trashCount,
      mcpBridgeStatus: mcpStatus,
      workQueueSummary: queueSummary,
      enabledMcpToolCount: enabledCount,
      disabledMcpToolCount: tools.length - enabledCount,
      recentWorkQueueActivities: queueActivities,
      executionSummary: executionSummary,
      integritySummary: integritySummary,
      reportConsistent: report.isConsistent,
      macSmokeStatus: macSmoke?.status,
      windowsSmokeStatus: winSmoke?.status,
      releaseReadiness: releaseReadiness,
      rcFinalization: rcFinalization,
    );
  }

  /// AI 협업 프로토콜 요약을 구성한다 (v0 local provider).
  AiCollaborationSummary _buildAiCollaborationSummary(
    CriticalAlertSummary critical,
    WorkQueueSummary queueSummary,
  ) {
    return AiCollaborationSummary(
      activeWorkInstructions: 0,
      handoffPending: critical.pendingExtractionCount > 0 || queueSummary.pendingCount > 0 ? 1 : 0,
      verificationNeeded: queueSummary.conflictCount > 0 ? 1 : 0,
      criticalIssues: critical.hasCritical || queueSummary.blockedCount > 0 ? 1 : 0,
      lastCompletedSprint: 'Sprint 11 RC Finalization',
    );
  }

  /// 최근 work queue 감사 활동을 조회한다.
  Future<List<RecentActivityItem>> _loadWorkQueueActivities() async {
    final rows = await _db.query(
      'audit_logs',
      where: "target_type = 'work_queue_ticket'",
      orderBy: 'occurred_at DESC',
      limit: 8,
    );
    return rows
        .map(
          (row) => RecentActivityItem(
            id: row['id'] as String,
            action: row['action'] as String? ?? 'unknown',
            targetType: row['target_type'] as String? ?? 'work_queue_ticket',
            targetId: row['target_id'] as String?,
            occurredAt: DateTime.parse(row['occurred_at'] as String).toLocal(),
          ),
        )
        .toList();
  }

  /// Critical / 충돌 알림 수치를 집계한다.
  Future<CriticalAlertSummary> _buildCriticalAlerts() async {
    final syncConflictCount = Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM sync_state WHERE status = 'conflict' OR conflict = 1",
          ),
        ) ??
        0;
    final pendingExtractionCount = Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM personal_extraction_queue WHERE status = 'pending'",
          ),
        ) ??
        0;
    final failedIndexingCount = Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM sync_state WHERE dirty = 1 AND status = 'dirty'",
          ),
        ) ??
        0;
    final privacyWarningCount = pendingExtractionCount;

    return CriticalAlertSummary(
      syncConflictCount: syncConflictCount,
      pendingExtractionCount: pendingExtractionCount,
      privacyWarningCount: privacyWarningCount,
      failedIndexingCount: failedIndexingCount,
    );
  }

  /// 개인 아카이브 항목 수를 집계한다.
  Future<(int, int)> _countPersonalArchive() async {
    final total = Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM personal_archive_items WHERE status != 'deleted'",
          ),
        ) ??
        0;
    final active = Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM personal_archive_items WHERE status = 'active'",
          ),
        ) ??
        0;
    return (total, active);
  }

  /// 최근 문서 태그를 수집한다.
  Future<List<String>> _collectRecentTags() async {
    final rows = await _db.query(
      'documents',
      columns: ['tags'],
      where: 'is_deleted = 0',
      orderBy: 'updated_at DESC',
      limit: 20,
    );
    final tagCounts = <String, int>{};
    for (final row in rows) {
      final raw = row['tags'] as String?;
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final tag in decoded) {
            final value = tag.toString().trim();
            if (value.isNotEmpty) {
              tagCounts[value] = (tagCounts[value] ?? 0) + 1;
            }
          }
        }
      } catch (_) {
        continue;
      }
    }
    final sorted = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(8).map((e) => e.key).toList();
  }

  /// 최근 감사 로그 활동을 조회한다.
  Future<List<RecentActivityItem>> _loadRecentActivities() async {
    final rows = await _db.query(
      'audit_logs',
      orderBy: 'occurred_at DESC',
      limit: 8,
    );
    return rows
        .map(
          (row) => RecentActivityItem(
            id: row['id'] as String,
            action: row['action'] as String? ?? 'unknown',
            targetType: row['target_type'] as String? ?? 'unknown',
            targetId: row['target_id'] as String?,
            occurredAt: DateTime.parse(row['occurred_at'] as String).toLocal(),
          ),
        )
        .toList();
  }
}
