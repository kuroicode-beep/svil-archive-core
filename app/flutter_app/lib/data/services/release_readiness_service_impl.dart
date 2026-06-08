// release_readiness_service_impl.dart — RC 준비 상태 평가 SQLite 구현

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/build_environment_check.dart';
import '../../domain/models/release_readiness.dart';
import '../../domain/models/smoke_test_record.dart';
import '../../domain/services/build_environment_check_service.dart';
import '../../domain/services/mcp_bridge_status_service.dart';
import '../../domain/services/queue_execution_service.dart';
import '../../domain/services/release_readiness_service.dart';
import '../../domain/services/report_consistency_service.dart';
import '../../domain/services/settings_service.dart';
import '../../domain/services/smoke_test_record_service.dart';
import '../../domain/services/work_queue_service.dart';
import '../../domain/services/workspace_integrity_service.dart';
import '../db/database_service_impl.dart';

class ReleaseReadinessServiceImpl implements ReleaseReadinessService {
  final DatabaseServiceImpl _databaseService;
  final WorkspaceIntegrityService _integrityService;
  final SmokeTestRecordService _smokeTestRecordService;
  final ReportConsistencyService _reportConsistencyService;
  final McpBridgeStatusService _mcpBridgeService;
  final WorkQueueService _workQueueService;
  final QueueExecutionService _queueExecutionService;
  final SettingsService _settingsService;
  final BuildEnvironmentCheckService _buildEnvironmentCheckService;
  final Uuid _uuid = const Uuid();

  ReleaseReadinessServiceImpl({
    required DatabaseServiceImpl databaseService,
    required WorkspaceIntegrityService integrityService,
    required SmokeTestRecordService smokeTestRecordService,
    required ReportConsistencyService reportConsistencyService,
    required McpBridgeStatusService mcpBridgeService,
    required WorkQueueService workQueueService,
    required QueueExecutionService queueExecutionService,
    required SettingsService settingsService,
    required BuildEnvironmentCheckService buildEnvironmentCheckService,
  })  : _databaseService = databaseService,
        _integrityService = integrityService,
        _smokeTestRecordService = smokeTestRecordService,
        _reportConsistencyService = reportConsistencyService,
        _mcpBridgeService = mcpBridgeService,
        _workQueueService = workQueueService,
        _queueExecutionService = queueExecutionService,
        _settingsService = settingsService,
        _buildEnvironmentCheckService = buildEnvironmentCheckService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<ReleaseReadinessSummary> evaluate() async {
    final checkedAt = DateTime.now().toUtc();
    final items = <ReadinessCheckItem>[];

    final integrity = await _integrityService.getLatestSummary();
    items.add(_integrityItem('orphan_markdown', integrity.openOrphanCount));
    items.add(_integrityItem('stale_db_row', integrity.openStaleDbCount));
    items.add(_conflictItem(integrity.openConflictCount));

    final report = await _reportConsistencyService.checkReports();
    items.add(
      ReadinessCheckItem(
        category: 'reports',
        label: 'Sprint 보고서 정합성',
        status: report.isConsistent ? ReadinessItemStatus.pass : ReadinessItemStatus.fail,
        detail: report.isConsistent ? null : '${report.mismatches.length} mismatch',
      ),
    );

    final macSmoke = await _smokeTestRecordService.getLatestForPlatform('macOS');
    final winSmoke = await _smokeTestRecordService.getLatestForPlatform('Windows');
    items.add(_smokeItem('macOS smoke', macSmoke));
    items.add(_smokeItem('Windows smoke', winSmoke));

    final mcp = await _mcpBridgeService.checkStatus();
    items.add(
      ReadinessCheckItem(
        category: 'mcp',
        label: 'MCP local-only',
        status: mcp.localOnly && !mcp.remoteExposureEnabled
            ? ReadinessItemStatus.pass
            : ReadinessItemStatus.fail,
        detail: mcp.label,
      ),
    );

    final queue = await _workQueueService.getSummary();
    items.add(
      ReadinessCheckItem(
        category: 'work_queue',
        label: 'blocked ticket',
        status: queue.blockedCount > 0 ? ReadinessItemStatus.warn : ReadinessItemStatus.pass,
        detail: '${queue.blockedCount} blocked',
      ),
    );
    items.add(
      ReadinessCheckItem(
        category: 'work_queue',
        label: 'conflict ticket',
        status: queue.conflictCount > 0 ? ReadinessItemStatus.fail : ReadinessItemStatus.pass,
        detail: '${queue.conflictCount} conflict',
      ),
    );

    final execution = await _queueExecutionService.getExecutionSummary();
    items.add(
      ReadinessCheckItem(
        category: 'execution',
        label: 'failed execution',
        status: execution.executionFailedCount > 0 ? ReadinessItemStatus.warn : ReadinessItemStatus.pass,
        detail: '${execution.executionFailedCount} failed',
      ),
    );

    final settings = await _settingsService.getSettings();
    items.add(
      ReadinessCheckItem(
        category: 'privacy',
        label: '외부 API 기본 OFF',
        status: !settings.externalApiEnabled ? ReadinessItemStatus.pass : ReadinessItemStatus.fail,
        detail: settings.externalApiEnabled ? 'enabled' : 'disabled',
      ),
    );

    final buildChecks = await _buildEnvironmentCheckService.runChecks();
    for (final check in buildChecks) {
      items.add(
        ReadinessCheckItem(
          category: 'build',
          label: check.checkName,
          status: _mapBuildStatus(check.status),
          detail: check.message,
        ),
      );
    }

    await _persistItems(items, checkedAt);
    return _summarize(items, checkedAt);
  }

  @override
  Future<ReleaseReadinessSummary?> getLatestSummary() async {
    final rows = await _db.query(
      'release_readiness_checks',
      orderBy: 'checked_at DESC',
    );
    if (rows.isEmpty) return null;
    final latestStamp = rows.first['checked_at'] as String;
    final items = rows
        .where((row) => row['checked_at'] == latestStamp)
        .map(_mapReadinessRow)
        .toList();
    return _summarize(items, DateTime.parse(latestStamp).toLocal());
  }

  /// 무결성 카운트를 readiness 항목으로 변환한다.
  ReadinessCheckItem _integrityItem(String label, int count) {
    return ReadinessCheckItem(
      category: 'integrity',
      label: label,
      status: count == 0 ? ReadinessItemStatus.pass : ReadinessItemStatus.warn,
      detail: '$count open',
    );
  }

  /// conflict 카운트를 readiness 항목으로 변환한다.
  ReadinessCheckItem _conflictItem(int count) {
    return ReadinessCheckItem(
      category: 'integrity',
      label: 'sync conflict',
      status: count == 0 ? ReadinessItemStatus.pass : ReadinessItemStatus.fail,
      detail: '$count open',
    );
  }

  /// smoke 기록을 readiness 항목으로 변환한다.
  ReadinessCheckItem _smokeItem(String label, SmokeTestRecord? record) {
    if (record == null) {
      return ReadinessCheckItem(
        category: 'smoke',
        label: label,
        status: ReadinessItemStatus.warn,
        detail: 'no record',
      );
    }
    switch (record.status) {
      case SmokeTestStatus.passed:
        return ReadinessCheckItem(
          category: 'smoke',
          label: label,
          status: ReadinessItemStatus.pass,
          detail: record.checklistName,
        );
      case SmokeTestStatus.failed:
        return ReadinessCheckItem(
          category: 'smoke',
          label: label,
          status: ReadinessItemStatus.fail,
          detail: record.notes,
        );
      case SmokeTestStatus.skipped:
        return ReadinessCheckItem(
          category: 'smoke',
          label: label,
          status: ReadinessItemStatus.warn,
          detail: 'skipped',
        );
      case SmokeTestStatus.pending:
        return ReadinessCheckItem(
          category: 'smoke',
          label: label,
          status: ReadinessItemStatus.warn,
          detail: 'pending',
        );
    }
  }

  /// BuildCheckStatus를 ReadinessItemStatus로 변환한다.
  ReadinessItemStatus _mapBuildStatus(BuildCheckStatus status) {
    switch (status) {
      case BuildCheckStatus.pass:
        return ReadinessItemStatus.pass;
      case BuildCheckStatus.warn:
        return ReadinessItemStatus.warn;
      case BuildCheckStatus.fail:
        return ReadinessItemStatus.fail;
    }
  }

  /// readiness 항목을 DB에 저장한다.
  Future<void> _persistItems(List<ReadinessCheckItem> items, DateTime checkedAt) async {
    final stamp = checkedAt.toIso8601String();
    final batch = _db.batch();
    for (final item in items) {
      batch.insert('release_readiness_checks', {
        'id': _uuid.v4(),
        'category': item.category,
        'label': item.label,
        'status': item.status.name,
        'detail': item.detail,
        'checked_at': stamp,
      });
    }
    await batch.commit(noResult: true);
  }

  /// 항목 목록으로 ReleaseReadinessSummary를 구성한다.
  ReleaseReadinessSummary _summarize(List<ReadinessCheckItem> items, DateTime checkedAt) {
    final passCount = items.where((i) => i.status == ReadinessItemStatus.pass).length;
    final warnCount = items.where((i) => i.status == ReadinessItemStatus.warn).length;
    final failCount = items.where((i) => i.status == ReadinessItemStatus.fail).length;
    return ReleaseReadinessSummary(
      isReadyForRc: failCount == 0,
      passCount: passCount,
      warnCount: warnCount,
      failCount: failCount,
      items: items,
      checkedAt: checkedAt.toLocal(),
    );
  }

  /// DB row를 ReadinessCheckItem으로 변환한다.
  ReadinessCheckItem _mapReadinessRow(Map<String, Object?> row) {
    return ReadinessCheckItem(
      category: row['category'] as String,
      label: row['label'] as String,
      status: ReadinessItemStatus.values.firstWhere(
        (s) => s.name == (row['status'] as String? ?? 'unknown'),
        orElse: () => ReadinessItemStatus.unknown,
      ),
      detail: row['detail'] as String?,
    );
  }
}
