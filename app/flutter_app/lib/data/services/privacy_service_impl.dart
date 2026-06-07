// privacy_service_impl.dart — 개인정보 보호 요약 SQLite 구현

import 'package:sqflite/sqflite.dart';

import '../../domain/models/dashboard.dart';
import '../../domain/services/privacy_service.dart';
import '../db/database_service_impl.dart';

class PrivacyServiceImpl implements PrivacyService {
  final DatabaseServiceImpl _databaseService;

  PrivacyServiceImpl({required DatabaseServiceImpl databaseService})
      : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<PrivacySummary> getPrivacySummary() async {
    final pendingCandidateCount = Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM personal_extraction_queue WHERE status = 'pending'",
          ),
        ) ??
        0;
    final rejectedCandidateCount = Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM personal_extraction_queue WHERE status = 'rejected'",
          ),
        ) ??
        0;
    final activePersonalItemCount = Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM personal_archive_items WHERE status = 'active'",
          ),
        ) ??
        0;
    final deletedPersonalItemCount = Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM personal_archive_items WHERE status = 'deleted'",
          ),
        ) ??
        0;

    final auditRows = await _db.query(
      'audit_logs',
      where: "target_type IN ('extraction_candidate', 'profile', 'approved', 'personal_archive_item') "
          "OR action IN ('approve', 'reject', 'edit_approve', 'create', 'delete', 'export')",
      orderBy: 'occurred_at DESC',
      limit: 10,
    );

    final logs = auditRows
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

    return PrivacySummary(
      localProcessingEnabled: true,
      externalTransferEnabled: false,
      pendingCandidateCount: pendingCandidateCount,
      rejectedCandidateCount: rejectedCandidateCount,
      activePersonalItemCount: activePersonalItemCount,
      deletedPersonalItemCount: deletedPersonalItemCount,
      recentPrivacyAuditLogs: logs,
      exportPolicyLabel: 'approved / active only — pending·rejected·deleted 제외',
    );
  }
}
