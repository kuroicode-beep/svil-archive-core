// rc_tag_readiness_service_impl.dart — RC tag readiness SQLite 구현

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/rc_build_approval.dart';
import '../../domain/models/rc_finalization.dart';
import '../../domain/services/rc_tag_readiness_service.dart';
import '../../domain/services/release_approval_service.dart';
import '../../domain/services/release_finalization_export_service.dart';
import '../../domain/services/release_readiness_service.dart';
import '../../domain/services/smoke_approval_service.dart';
import '../../domain/services/verification_pass_record_service.dart';
import '../db/database_service_impl.dart';

class RcTagReadinessServiceImpl implements RcTagReadinessService {
  final DatabaseServiceImpl _databaseService;
  final ReleaseReadinessService _releaseReadinessService;
  final VerificationPassRecordService _verificationService;
  final ReleaseFinalizationExportService _exportService;
  final SmokeApprovalService _smokeApprovalService;
  final ReleaseApprovalService _releaseApprovalService;
  final Uuid _uuid = const Uuid();

  RcTagReadinessServiceImpl({
    required DatabaseServiceImpl databaseService,
    required ReleaseReadinessService releaseReadinessService,
    required VerificationPassRecordService verificationService,
    required ReleaseFinalizationExportService exportService,
    required SmokeApprovalService smokeApprovalService,
    required ReleaseApprovalService releaseApprovalService,
  })  : _databaseService = databaseService,
        _releaseReadinessService = releaseReadinessService,
        _verificationService = verificationService,
        _exportService = exportService,
        _smokeApprovalService = smokeApprovalService,
        _releaseApprovalService = releaseApprovalService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<RcTagReadinessSummary> runRcTagReadinessChecks() async {
    final runId = _uuid.v4();
    final checkedAt = DateTime.now().toUtc();
    final readiness = await _releaseReadinessService.evaluate();
    final exportStatus = await _exportService.getExportStatus();
    final verificationComplete = await _verificationService.hasCompleteVerificationSet();
    final smoke = await _smokeApprovalService.getSmokeApprovalSummary();
    final approval = await _releaseApprovalService.evaluateAndPersist();

    final checks = <({String label, bool passed, String? detail})>[
      (label: 'Sprint 11 PASS 확인', passed: readiness.rcFinalizationStatus != RcFinalizationStatus.blocked, detail: null),
      (label: 'analyze PASS 기록', passed: verificationComplete, detail: null),
      (label: 'test PASS 기록', passed: verificationComplete, detail: null),
      (label: 'sidecar build PASS 기록', passed: verificationComplete, detail: null),
      (label: 'release notes 생성', passed: exportStatus.releaseNotesExported, detail: null),
      (label: 'known issues 생성', passed: exportStatus.knownIssuesExported, detail: null),
      (label: 'Windows smoke 상태 기록', passed: smoke.windowsRecorded, detail: smoke.windowsStatus?.name),
      (label: 'macOS smoke 상태 기록', passed: smoke.macRecorded, detail: smoke.macStatus?.name),
      (label: 'RC tag readiness checklist 생성', passed: exportStatus.tagReadinessExported, detail: null),
      (label: 'RC 판정 ready', passed: readiness.rcFinalizationStatus == RcFinalizationStatus.ready, detail: readiness.rcStatusLabel),
      (label: 'Release approval ready_for_approval', passed: approval.status == ReleaseApprovalStatus.readyForApproval || approval.status == ReleaseApprovalStatus.approved, detail: approval.statusLabel),
      (label: 'Git tag 자동 생성 없음', passed: true, detail: 'manual only'),
      (label: 'Notion 완료보고서 작성', passed: false, detail: 'pending'),
      (label: 'Codex 검증 보고서 작성', passed: false, detail: 'pending'),
    ];

    final items = <RcTagReadinessCheckItem>[];
    for (final check in checks) {
      final id = _uuid.v4();
      final stamp = checkedAt.toIso8601String();
      await _db.insert('rc_tag_readiness_checks', {
        'id': id,
        'run_id': runId,
        'check_label': check.label,
        'passed': check.passed ? 1 : 0,
        'detail': check.detail,
        'checked_at': stamp,
      });
      items.add(
        RcTagReadinessCheckItem(
          id: id,
          checkLabel: check.label,
          passed: check.passed,
          detail: check.detail,
          checkedAt: checkedAt.toLocal(),
        ),
      );
    }

    return RcTagReadinessSummary(
      runId: runId,
      items: items,
      allPassed: items.every((i) => i.passed),
      checkedAt: checkedAt.toLocal(),
    );
  }

  @override
  Future<RcTagReadinessSummary?> getLatestSummary() async {
    final rows = await _db.query(
      'rc_tag_readiness_checks',
      orderBy: 'checked_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final runId = rows.first['run_id'] as String;
    final allRows = await _db.query(
      'rc_tag_readiness_checks',
      where: 'run_id = ?',
      whereArgs: [runId],
      orderBy: 'checked_at ASC',
    );
    final items = allRows
        .map(
          (row) => RcTagReadinessCheckItem(
            id: row['id'] as String,
            checkLabel: row['check_label'] as String,
            passed: (row['passed'] as int? ?? 0) == 1,
            detail: row['detail'] as String?,
            checkedAt: DateTime.parse(row['checked_at'] as String).toLocal(),
          ),
        )
        .toList();
    return RcTagReadinessSummary(
      runId: runId,
      items: items,
      allPassed: items.every((i) => i.passed),
      checkedAt: items.last.checkedAt,
    );
  }
}
