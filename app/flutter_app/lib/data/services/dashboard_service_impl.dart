// dashboard_service_impl.dart — 대시보드 요약 SQLite 구현

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/dashboard.dart';
import '../../domain/services/dashboard_service.dart';
import '../db/database_service_impl.dart';

class DashboardServiceImpl implements DashboardService {
  final DatabaseServiceImpl _databaseService;

  DashboardServiceImpl({required DatabaseServiceImpl databaseService})
      : _databaseService = databaseService;

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

    return DashboardSummary(
      aiCollaboration: _buildAiCollaborationSummary(critical),
      criticalAlerts: critical,
      personalArchiveItemCount: personalCounts.$1,
      approvedPersonalItemCount: personalCounts.$2,
      recentTags: recentTags,
      recentActivities: recentActivities,
      documentCount: documentCount,
      trashCount: trashCount,
    );
  }

  /// AI 협업 프로토콜 요약을 구성한다 (v0 local provider).
  AiCollaborationSummary _buildAiCollaborationSummary(CriticalAlertSummary critical) {
    return AiCollaborationSummary(
      activeWorkInstructions: 0,
      handoffPending: critical.pendingExtractionCount > 0 ? 1 : 0,
      verificationNeeded: 0,
      criticalIssues: critical.hasCritical ? 1 : 0,
      lastCompletedSprint: 'Sprint 05 Personal Archive',
    );
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
