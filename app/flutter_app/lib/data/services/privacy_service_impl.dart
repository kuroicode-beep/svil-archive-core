// privacy_service_impl.dart — 개인정보 보호 요약 SQLite 구현

import 'package:sqflite/sqflite.dart';

import '../../domain/models/dashboard.dart';
import '../../domain/models/rc_finalization.dart';
import '../../domain/models/work_queue.dart';
import '../../domain/services/mcp_bridge_status_service.dart';
import '../../domain/services/mcp_tool_registry_service.dart';
import '../../domain/services/permission_token_service.dart';
import '../../domain/services/privacy_service.dart';
import '../../domain/services/queue_execution_service.dart';
import '../../domain/services/release_readiness_service.dart';
import '../../domain/services/report_consistency_service.dart';
import '../../domain/services/workspace_integrity_service.dart';
import '../db/database_service_impl.dart';

class PrivacyServiceImpl implements PrivacyService {
  final DatabaseServiceImpl _databaseService;
  final PermissionTokenService _permissionTokenService;
  final McpToolRegistryService _toolRegistryService;
  final McpBridgeStatusService _mcpBridgeService;
  final QueueExecutionService _queueExecutionService;
  final WorkspaceIntegrityService _integrityService;
  final ReportConsistencyService _reportConsistencyService;
  final ReleaseReadinessService _releaseReadinessService;

  PrivacyServiceImpl({
    required DatabaseServiceImpl databaseService,
    required PermissionTokenService permissionTokenService,
    required McpToolRegistryService toolRegistryService,
    required McpBridgeStatusService mcpBridgeService,
    required QueueExecutionService queueExecutionService,
    required WorkspaceIntegrityService integrityService,
    required ReportConsistencyService reportConsistencyService,
    required ReleaseReadinessService releaseReadinessService,
  })  : _databaseService = databaseService,
        _permissionTokenService = permissionTokenService,
        _toolRegistryService = toolRegistryService,
        _mcpBridgeService = mcpBridgeService,
        _queueExecutionService = queueExecutionService,
        _integrityService = integrityService,
        _reportConsistencyService = reportConsistencyService,
        _releaseReadinessService = releaseReadinessService;

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

    final mcpStatus = await _mcpBridgeService.checkStatus();
    final tools = await _toolRegistryService.listTools();
    final enabledCount = tools.where((t) => t.enabled).length;

    final executionSummary = await _queueExecutionService.getExecutionSummary();
    final integritySummary = await _integrityService.getLatestSummary();
    final report = await _reportConsistencyService.checkReports();
    final releaseReadiness = await _releaseReadinessService.getLatestSummary();

    return PrivacySummary(
      localProcessingEnabled: true,
      externalTransferEnabled: false,
      pendingCandidateCount: pendingCandidateCount,
      rejectedCandidateCount: rejectedCandidateCount,
      activePersonalItemCount: activePersonalItemCount,
      deletedPersonalItemCount: deletedPersonalItemCount,
      recentPrivacyAuditLogs: logs,
      exportPolicyLabel: 'approved / active only — pending·rejected·deleted 제외',
      mcpPrivacy: McpPrivacySummary(
        localOnly: mcpStatus.localOnly,
        remoteMcpEnabled: mcpStatus.remoteExposureEnabled,
        writeTokenCount: await _permissionTokenService.countActiveByType(PermissionLevel.write),
        destructiveTokenCount:
            await _permissionTokenService.countActiveByType(PermissionLevel.destructive),
        personalTokenCount:
            await _permissionTokenService.countActiveByType(PermissionLevel.personal),
        enabledToolCount: enabledCount,
        disabledToolCount: tools.length - enabledCount,
      ),
      executionSummary: executionSummary,
      integritySummary: integritySummary,
      reportConsistent: report.isConsistent,
      releaseReadiness: releaseReadiness,
      releaseBlockingCount: releaseReadiness?.rcFinalizationStatus == RcFinalizationStatus.blocked
          ? (releaseReadiness?.failCount ?? 1)
          : 0,
      releaseExportPolicyLabel: 'release notes / known issues: 개인 본문·secret 미포함',
      knownIssuesPolicyLabel: 'external API OFF / remote MCP OFF / active-only export 유지',
    );
  }
}
