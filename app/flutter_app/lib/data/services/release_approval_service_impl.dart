// release_approval_service_impl.dart — Release approval SQLite 구현

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/rc_build_approval.dart';
import '../../domain/services/release_approval_service.dart';
import '../../domain/services/release_finalization_export_service.dart';
import '../../domain/services/release_readiness_service.dart';
import '../../domain/services/smoke_approval_service.dart';
import '../../domain/services/verification_pass_record_service.dart';
import '../../domain/services/workspace_integrity_service.dart';
import '../../domain/utils/release_approval_policy.dart';
import '../db/database_service_impl.dart';
import 'report_consistency_service_impl.dart';

class ReleaseApprovalServiceImpl implements ReleaseApprovalService {
  final DatabaseServiceImpl _databaseService;
  final ReleaseReadinessService _releaseReadinessService;
  final ReleaseFinalizationExportService _exportService;
  final VerificationPassRecordService _verificationService;
  final SmokeApprovalService _smokeApprovalService;
  final WorkspaceIntegrityService _integrityService;
  final Uuid _uuid = const Uuid();

  ReleaseApprovalServiceImpl({
    required DatabaseServiceImpl databaseService,
    required ReleaseReadinessService releaseReadinessService,
    required ReleaseFinalizationExportService exportService,
    required VerificationPassRecordService verificationService,
    required SmokeApprovalService smokeApprovalService,
    required WorkspaceIntegrityService integrityService,
  })  : _databaseService = databaseService,
        _releaseReadinessService = releaseReadinessService,
        _exportService = exportService,
        _verificationService = verificationService,
        _smokeApprovalService = smokeApprovalService,
        _integrityService = integrityService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<ReleaseApprovalSummary> evaluateAndPersist() async {
    final summary = await _computeSummary();
    final latest = await getLatestSummary();
    if (latest != null &&
        latest.status == summary.status &&
        latest.statusLabel == summary.statusLabel) {
      return latest;
    }
    await _insertRecord(summary);
    return summary;
  }

  @override
  Future<ReleaseApprovalSummary?> getLatestSummary() async {
    final rows = await _db.query(
      'release_approval_records',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  @override
  Future<ReleaseApprovalSummary> recordDecision({
    required ReleaseApprovalStatus decision,
    String? notes,
    String? approvedBy,
  }) async {
    if (decision != ReleaseApprovalStatus.approved &&
        decision != ReleaseApprovalStatus.rejected) {
      throw ArgumentError('decision must be approved or rejected');
    }
    final now = DateTime.now().toUtc();
    final summary = ReleaseApprovalSummary(
      id: _uuid.v4(),
      status: decision,
      statusLabel: releaseApprovalStatusLabel(decision),
      rcCommitHash: kRcVerificationSprintCommit,
      notes: notes,
      approvedBy: approvedBy ?? 'user',
      createdAt: now.toLocal(),
      updatedAt: now.toLocal(),
    );
    await _insertRecord(summary);
    return summary;
  }

  /// 현재 조건으로 approval 요약을 계산한다.
  Future<ReleaseApprovalSummary> _computeSummary() async {
    final readiness = await _releaseReadinessService.evaluate();
    final exportStatus = await _exportService.getExportStatus();
    final verificationComplete = await _verificationService.hasCompleteVerificationSet();
    final smoke = await _smokeApprovalService.getSmokeApprovalSummary();
    final integrity = await _integrityService.getLatestSummary();
    final integrityCritical = integrity.openConflictCount > 0 || readiness.failCount > 0;
    final latest = await getLatestSummary();
    ReleaseApprovalStatus? sticky;
    if (latest?.status == ReleaseApprovalStatus.approved ||
        latest?.status == ReleaseApprovalStatus.rejected) {
      sticky = latest!.status;
    }
    final status = computeReleaseApprovalStatus(
      rcFinalizationStatus: readiness.rcFinalizationStatus,
      verificationComplete: verificationComplete,
      releaseNotesExported: exportStatus.releaseNotesExported,
      knownIssuesExported: exportStatus.knownIssuesExported,
      tagReadinessExported: exportStatus.tagReadinessExported,
      macSmokeStatus: smoke.macStatus,
      winSmokeStatus: smoke.windowsStatus,
      integrityCritical: integrityCritical,
      stickyManualStatus: sticky,
    );
    final now = DateTime.now().toUtc();
    return ReleaseApprovalSummary(
      id: _uuid.v4(),
      status: status,
      statusLabel: releaseApprovalStatusLabel(status),
      rcCommitHash: kRcVerificationSprintCommit,
      createdAt: now.toLocal(),
      updatedAt: now.toLocal(),
    );
  }

  /// approval 레코드를 DB에 삽입한다.
  Future<void> _insertRecord(ReleaseApprovalSummary summary) async {
    final stamp = summary.updatedAt.toUtc().toIso8601String();
    await _db.insert('release_approval_records', {
      'id': summary.id,
      'status': summary.status.name,
      'status_label': summary.statusLabel,
      'rc_commit_hash': summary.rcCommitHash,
      'notes': summary.notes,
      'approved_by': summary.approvedBy,
      'created_at': stamp,
      'updated_at': stamp,
    });
  }

  /// DB row를 ReleaseApprovalSummary로 변환한다.
  ReleaseApprovalSummary _mapRow(Map<String, Object?> row) {
    return ReleaseApprovalSummary(
      id: row['id'] as String,
      status: ReleaseApprovalStatus.values.firstWhere(
        (s) => s.name == (row['status'] as String? ?? 'draft'),
        orElse: () => ReleaseApprovalStatus.draft,
      ),
      statusLabel: row['status_label'] as String? ?? '',
      rcCommitHash: row['rc_commit_hash'] as String? ?? '',
      notes: row['notes'] as String?,
      approvedBy: row['approved_by'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }
}
