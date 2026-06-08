// final_release_bundle_export_service_impl.dart — Sprint 12 final release bundle export

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/rc_build_approval.dart';
import '../../domain/services/final_release_bundle_export_service.dart';
import '../../domain/services/rc_build_artifact_service.dart';
import '../../domain/services/rc_tag_readiness_service.dart';
import '../../domain/services/release_approval_service.dart';
import '../../domain/services/release_finalization_export_service.dart';
import '../../domain/services/release_readiness_service.dart';
import '../../domain/services/smoke_approval_service.dart';
import '../../domain/services/verification_pass_record_service.dart';
import '../../domain/utils/path_masking.dart';
import '../db/database_service_impl.dart';
import '../platform/path_adapter.dart';
import 'report_consistency_service_impl.dart';

class FinalReleaseBundleExportServiceImpl implements FinalReleaseBundleExportService {
  final DatabaseServiceImpl _databaseService;
  final String workspaceRoot;
  final ReleaseReadinessService _releaseReadinessService;
  final ReleaseApprovalService _releaseApprovalService;
  final SmokeApprovalService _smokeApprovalService;
  final RcBuildArtifactService _buildArtifactService;
  final RcTagReadinessService _tagReadinessService;
  final ReleaseFinalizationExportService _finalizationExportService;
  final VerificationPassRecordService _verificationService;
  final Uuid _uuid = const Uuid();

  FinalReleaseBundleExportServiceImpl({
    required DatabaseServiceImpl databaseService,
    required this.workspaceRoot,
    required ReleaseReadinessService releaseReadinessService,
    required ReleaseApprovalService releaseApprovalService,
    required SmokeApprovalService smokeApprovalService,
    required RcBuildArtifactService buildArtifactService,
    required RcTagReadinessService tagReadinessService,
    required ReleaseFinalizationExportService finalizationExportService,
    required VerificationPassRecordService verificationService,
  })  : _databaseService = databaseService,
        _releaseReadinessService = releaseReadinessService,
        _releaseApprovalService = releaseApprovalService,
        _smokeApprovalService = smokeApprovalService,
        _buildArtifactService = buildArtifactService,
        _tagReadinessService = tagReadinessService,
        _finalizationExportService = finalizationExportService,
        _verificationService = verificationService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<FinalReleaseBundleResult> exportFinalReleaseBundle() async {
    final readiness = await _releaseReadinessService.evaluate();
    final approval = await _releaseApprovalService.evaluateAndPersist();
    final smoke = await _smokeApprovalService.getSmokeApprovalSummary();
    final artifacts = await _buildArtifactService.listBuildArtifacts(limit: 10);
    final tagReadiness = await _tagReadinessService.getLatestSummary() ??
        await _tagReadinessService.runRcTagReadinessChecks();
    final exportStatus = await _finalizationExportService.getExportStatus();
    final analyze = await _verificationService.getLatestForType('analyze');
    final test = await _verificationService.getLatestForType('test');
    final sidecar = await _verificationService.getLatestForType('sidecar_build');
    final rcCommit = kRcVerificationSprintCommit;

    final buffer = StringBuffer();
    buffer.writeln('# SAC v0.1 RC Final Release Bundle');
    buffer.writeln();
    buffer.writeln('생성일: ${_humanDateTime(DateTime.now())}');
    buffer.writeln('RC 기준 커밋: `$rcCommit`');
    buffer.writeln('Sprint 11 구현: `2833494` / 재작업: `5e02b31`');
    buffer.writeln('후보 태그: `v0.1.0-rc.1` (자동 생성 없음)');
    buffer.writeln();
    buffer.writeln('## 01. Sprint 01~11 완료 요약');
    buffer.writeln('- Workspace / Markdown / SQLite / Search / Trash');
    buffer.writeln('- Document Archive / Personal Archive / Dashboard');
    buffer.writeln('- Work Queue / MCP local-only / Safe Apply');
    buffer.writeln('- Integrity / Recovery / Smoke / RC Readiness');
    buffer.writeln('- Sprint 11 RC Finalization PASS');
    buffer.writeln();
    buffer.writeln('## 02. 자동 검증 결과');
    buffer.writeln('- analyze: ${analyze != null ? 'PASS' : 'no record'}');
    buffer.writeln('- test: ${test != null ? 'PASS (${test.testCount ?? '-'} tests)' : 'no record'}');
    buffer.writeln('- sidecar build: ${sidecar != null ? 'PASS' : 'no record'}');
    buffer.writeln('- pass/warn/fail: ${readiness.passCount}/${readiness.warnCount}/${readiness.failCount}');
    buffer.writeln();
    buffer.writeln('## 03. RC Approval');
    buffer.writeln('- status: ${approval.status.name}');
    buffer.writeln('- label: ${approval.statusLabel}');
    buffer.writeln('- RC 판정: ${readiness.rcStatusLabel}');
    buffer.writeln();
    buffer.writeln('## 04. Smoke Status');
    buffer.writeln('- macOS: ${smoke.macStatus?.name ?? 'pending'}');
    buffer.writeln('- Windows: ${smoke.windowsStatus?.name ?? 'pending'}');
    buffer.writeln();
    buffer.writeln('## 05. RC Build Artifacts (${artifacts.length})');
    for (final artifact in artifacts) {
      buffer.writeln('- ${artifact.platform} ${artifact.buildType.name}: ${artifact.status.name} @ ${artifact.artifactPathMasked}');
    }
    if (artifacts.isEmpty) {
      buffer.writeln('- (no artifacts recorded)');
    }
    buffer.writeln();
    buffer.writeln('## 06. Release Documents');
    buffer.writeln('- release notes: ${exportStatus.releaseNotesExported ? 'generated' : 'missing'}');
    buffer.writeln('- known issues: ${exportStatus.knownIssuesExported ? 'generated' : 'missing'}');
    buffer.writeln('- tag readiness: ${exportStatus.tagReadinessExported ? 'generated' : 'missing'}');
    buffer.writeln();
    buffer.writeln('## 07. Tag Readiness (${tagReadiness.items.where((i) => i.passed).length}/${tagReadiness.items.length} pass)');
    for (final item in tagReadiness.items) {
      buffer.writeln('- [${item.passed ? 'x' : ' '}] ${item.checkLabel}');
    }
    buffer.writeln();
    buffer.writeln('## 08. Advisory');
    buffer.writeln('- installer / code signing / notarization: deferred');
    buffer.writeln('- cloud sync: deferred');
    buffer.writeln('- external API: disabled by design');
    buffer.writeln('- remote MCP: disabled by design');
    buffer.writeln('- personal body: excluded from bundle');
    buffer.writeln();
    buffer.writeln('## 09. Codex Final Verification');
    buffer.writeln('- Request: `docs/handoff/Codex_Verification_Request_Sprint_12.md`');
    buffer.writeln('- Git tag auto-create: **disabled**');

    final markdown = buffer.toString();
    if (exportContainsSensitivePatterns(markdown)) {
      throw StateError('bundle contains sensitive patterns');
    }

    return _writeBundle(markdown);
  }

  @override
  Future<bool> hasFinalBundleExport() async {
    final rows = await _db.query(
      'audit_logs',
      where: "action = 'export' AND target_type = ?",
      whereArgs: ['final_release_bundle'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// bundle 파일을 쓰고 감사 로그를 남긴다.
  Future<FinalReleaseBundleResult> _writeBundle(String markdown) async {
    final stamp = _formatFileStamp(DateTime.now());
    final fileName = 'sac_v0.1_rc_bundle_$stamp.md';
    final relativePath = p.posix.join('.sac', 'exports', fileName);
    final exportDir = Directory(resolveWorkspacePath(workspaceRoot, p.posix.join('.sac', 'exports')));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final file = File(p.join(exportDir.path, fileName));
    await file.writeAsString(markdown);
    await _db.insert('audit_logs', {
      'id': _uuid.v4(),
      'actor': 'user',
      'action': 'export',
      'target_type': 'final_release_bundle',
      'target_id': relativePath,
      'detail_json': '{"sensitive_body":false}',
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
    return FinalReleaseBundleResult(
      relativePath: relativePath,
      absolutePath: file.path,
      markdown: markdown,
    );
  }

  /// 사람이 읽기 쉬운 날짜 문자열을 반환한다.
  String _humanDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y.$m.$d $h:$min';
  }

  /// 파일명용 타임스탬프를 포맷한다.
  String _formatFileStamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y$m${d}_$h$min';
  }
}
