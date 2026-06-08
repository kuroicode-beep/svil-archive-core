// release_finalization_export_service_impl.dart — Sprint 11 RC 문서 export 구현

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/rc_finalization.dart';
import '../../domain/models/smoke_test_record.dart';
import '../../domain/services/release_finalization_export_service.dart';
import '../../domain/services/release_readiness_service.dart';
import '../../domain/services/smoke_test_record_service.dart';
import '../../domain/services/verification_pass_record_service.dart';
import '../db/database_service_impl.dart';
import '../platform/path_adapter.dart';
import 'report_consistency_service_impl.dart';

class ReleaseFinalizationExportServiceImpl implements ReleaseFinalizationExportService {
  final DatabaseServiceImpl _databaseService;
  final String workspaceRoot;
  final ReleaseReadinessService _releaseReadinessService;
  final VerificationPassRecordService _verificationPassRecordService;
  final SmokeTestRecordService _smokeTestRecordService;
  final Uuid _uuid = const Uuid();

  ReleaseFinalizationExportServiceImpl({
    required DatabaseServiceImpl databaseService,
    required this.workspaceRoot,
    required ReleaseReadinessService releaseReadinessService,
    required VerificationPassRecordService verificationPassRecordService,
    required SmokeTestRecordService smokeTestRecordService,
  })  : _databaseService = databaseService,
        _releaseReadinessService = releaseReadinessService,
        _verificationPassRecordService = verificationPassRecordService,
        _smokeTestRecordService = smokeTestRecordService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<ReleaseMarkdownExportResult> exportReleaseNotes() async {
    final readiness = await _releaseReadinessService.evaluate();
    final sprintCommit = kSprintReportCommitManifest['Sprint 10'] ?? 'unknown';
    final analyze = await _verificationPassRecordService.getLatestForType('analyze');
    final test = await _verificationPassRecordService.getLatestForType('test');
    final sidecar = await _verificationPassRecordService.getLatestForType('sidecar_build');
    final macSmoke = await _smokeTestRecordService.getLatestForPlatform('macOS');
    final winSmoke = await _smokeTestRecordService.getLatestForPlatform('Windows');

    final buffer = StringBuffer();
    buffer.writeln('# SAC v0.1 RC Release Notes');
    buffer.writeln();
    buffer.writeln('생성일: ${_humanDateTime(DateTime.now())}');
    buffer.writeln('기준 커밋: $sprintCommit');
    buffer.writeln('상태: RC Candidate');
    buffer.writeln('RC 판정: ${readiness.rcStatusLabel}');
    buffer.writeln();
    buffer.writeln('## 01. 주요 기능');
    buffer.writeln('- Workspace Markdown CRUD + SQLite 인덱싱');
    buffer.writeln('- FTS 검색 / 휴지통 / sync metadata');
    buffer.writeln('- MCP local-only + Work Queue + Safe Apply');
    buffer.writeln('- Personal Archive 수동 승인 / Privacy 보호');
    buffer.writeln('- Integrity scan / Recovery / Smoke 기록');
    buffer.writeln('- RC readiness / Settings / Release checklist');
    buffer.writeln();
    buffer.writeln('## 02. 보안 / 개인정보 정책');
    buffer.writeln('- 외부 API: 기본 OFF');
    buffer.writeln('- remote MCP: 비활성');
    buffer.writeln('- personal export: active-only');
    buffer.writeln('- release notes에 개인 본문 미포함');
    buffer.writeln();
    buffer.writeln('## 03. 접근성 기준');
    buffer.writeln('- 최소 폰트 16px / 터치 타겟 50px');
    buffer.writeln('- RC 상태 텍스트 라벨 표시');
    buffer.writeln();
    buffer.writeln('## 04. AI / MCP 통제 구조');
    buffer.writeln('- write/destructive: queue + token 승인');
    buffer.writeln('- MCP tool on/off registry');
    buffer.writeln();
    buffer.writeln('## 05. 알려진 제한사항');
    buffer.writeln('- installer / code signing / notarization 미포함');
    buffer.writeln('- cloud sync 미포함');
    buffer.writeln('- Git tag 자동 생성 없음');
    buffer.writeln();
    buffer.writeln('## 06. Smoke Test 상태');
    buffer.writeln('- macOS: ${_smokeLine(macSmoke)}');
    buffer.writeln('- Windows: ${_smokeLine(winSmoke)}');
    buffer.writeln();
    buffer.writeln('## 07. 검증 결과');
    buffer.writeln('- analyze: ${_verificationLine(analyze)}');
    buffer.writeln('- test: ${_verificationLine(test)}');
    buffer.writeln('- sidecar build: ${_verificationLine(sidecar)}');
    buffer.writeln('- pass/warn/fail: ${readiness.passCount}/${readiness.warnCount}/${readiness.failCount}');

    return _writeExport(
      filePrefix: 'release_notes_v0.1_rc',
      markdown: buffer.toString(),
      auditTargetType: 'release_notes',
    );
  }

  @override
  Future<ReleaseMarkdownExportResult> exportKnownIssues() async {
    final macSmoke = await _smokeTestRecordService.getLatestForPlatform('macOS');
    final winSmoke = await _smokeTestRecordService.getLatestForPlatform('Windows');
    final readiness = await _releaseReadinessService.getLatestSummary();

    final buffer = StringBuffer();
    buffer.writeln('# SAC v0.1 RC Known Issues');
    buffer.writeln();
    buffer.writeln('생성일: ${_humanDateTime(DateTime.now())}');
    buffer.writeln();
    _appendKnownIssue(
      buffer,
      id: 'KI-001',
      title: 'macOS smoke 상태',
      status: macSmoke?.status == SmokeTestStatus.passed ? 'accepted' : 'open',
      impact: macSmoke == null ? 'medium' : 'low',
      description: _smokeLine(macSmoke),
      response: '소장님 Integrity 화면에서 PASS/FAIL/SKIP 기록',
    );
    _appendKnownIssue(
      buffer,
      id: 'KI-002',
      title: 'Windows smoke 상태',
      status: winSmoke?.status == SmokeTestStatus.passed ? 'accepted' : 'open',
      impact: winSmoke == null ? 'medium' : 'low',
      description: _smokeLine(winSmoke),
      response: '소장님 Integrity 화면에서 PASS/FAIL/SKIP 기록',
    );
    _appendKnownIssue(
      buffer,
      id: 'KI-003',
      title: 'Ollama 미실행 시 offline 표시',
      status: 'accepted',
      impact: 'low',
      description: 'Local AI는 endpoint 미응답 시 offline으로 표시된다.',
      response: 'Ollama 실행 후 Settings에서 endpoint 확인',
    );
    _appendKnownIssue(
      buffer,
      id: 'KI-004',
      title: 'external API disabled by design',
      status: 'accepted',
      impact: 'low',
      description: '외부 API는 기본 OFF이며 자동 호출하지 않는다.',
      response: 'Settings에서 명시적 활성화 전까지 OFF 유지',
    );
    _appendKnownIssue(
      buffer,
      id: 'KI-005',
      title: 'remote MCP disabled by design',
      status: 'accepted',
      impact: 'low',
      description: 'MCP는 local-only sidecar만 허용한다.',
      response: 'remote exposure 비활성 유지',
    );
    _appendKnownIssue(
      buffer,
      id: 'KI-006',
      title: 'installer / code signing / notarization 미포함',
      status: 'deferred',
      impact: 'medium',
      description: 'Sprint 11은 RC 문서화만 수행하며 배포 자동화는 범위 외다.',
      response: '소장님 승인 후 별도 Sprint 또는 수동 작업',
    );
    _appendKnownIssue(
      buffer,
      id: 'KI-007',
      title: 'cloud sync 미포함',
      status: 'deferred',
      impact: 'low',
      description: 'Phase 1은 로컬 workspace만 지원한다.',
      response: 'Phase 2 후보로 기록',
    );
    _appendKnownIssue(
      buffer,
      id: 'KI-008',
      title: '영구 삭제 미포함',
      status: 'accepted',
      impact: 'low',
      description: '삭제는 휴지통 이동 정책을 따른다.',
      response: '휴지통 복구 흐름 사용',
    );
    if (readiness?.verificationCommitMismatch == true) {
      _appendKnownIssue(
        buffer,
        id: 'KI-009',
        title: '검증 기록 커밋 불일치',
        status: 'open',
        impact: 'medium',
        description: '최근 analyze/test/build 기록의 sprint commit이 manifest와 다르다.',
        response: '최신 검증 기록을 다시 저장',
      );
    }

    return _writeExport(
      filePrefix: 'known_issues_v0.1_rc',
      markdown: buffer.toString(),
      auditTargetType: 'known_issues',
    );
  }

  @override
  Future<ReleaseMarkdownExportResult> exportTagReadinessChecklist() async {
    final exportStatus = await getExportStatus();
    final readiness = await _releaseReadinessService.evaluate();
    final complete = await _verificationPassRecordService.hasCompleteVerificationSet();
    final macSmoke = await _smokeTestRecordService.getLatestForPlatform('macOS');
    final winSmoke = await _smokeTestRecordService.getLatestForPlatform('Windows');

    final buffer = StringBuffer();
    buffer.writeln('# SAC v0.1 RC Tag Readiness Checklist');
    buffer.writeln();
    buffer.writeln('후보 태그: `v0.1.0-rc.1`');
    buffer.writeln('주의: Git tag는 자동 생성하지 않는다. 소장님 승인 후 수동 생성.');
    buffer.writeln();
    _check(buffer, 'Sprint 10B PASS 확인', true);
    _check(buffer, 'Sprint 11 PASS 확인', readiness.rcFinalizationStatus != RcFinalizationStatus.blocked);
    _check(buffer, 'analyze PASS 기록', complete);
    _check(buffer, 'test PASS 기록', complete);
    _check(buffer, 'sidecar build PASS 기록', complete);
    _check(buffer, 'release notes 생성', exportStatus.releaseNotesExported);
    _check(buffer, 'known issues 생성', exportStatus.knownIssuesExported);
    _check(buffer, 'Windows smoke 상태 기록', winSmoke != null);
    _check(buffer, 'macOS smoke 상태 기록', macSmoke != null);
    _check(buffer, 'release checklist 생성 가능', true);
    _check(buffer, 'RC 판정 ready', readiness.rcFinalizationStatus == RcFinalizationStatus.ready);
    _check(buffer, 'Notion 완료보고서 작성', false);
    _check(buffer, 'Codex 검증 보고서 작성', false);

    return _writeExport(
      filePrefix: 'rc_tag_readiness_v0.1',
      markdown: buffer.toString(),
      auditTargetType: 'rc_tag_readiness',
    );
  }

  @override
  Future<ReleaseExportStatus> getExportStatus() async {
    final notes = await _latestExportTime('release_notes');
    final issues = await _latestExportTime('known_issues');
    final tag = await _latestExportTime('rc_tag_readiness');
    return ReleaseExportStatus(
      releaseNotesExported: notes != null,
      knownIssuesExported: issues != null,
      tagReadinessExported: tag != null,
      releaseNotesExportedAt: notes,
      knownIssuesExportedAt: issues,
      tagReadinessExportedAt: tag,
    );
  }

  /// known issue 블록을 추가한다.
  void _appendKnownIssue(
    StringBuffer buffer, {
    required String id,
    required String title,
    required String status,
    required String impact,
    required String description,
    required String response,
  }) {
    buffer.writeln('## $id. $title');
    buffer.writeln();
    buffer.writeln('상태: $status');
    buffer.writeln('영향: $impact');
    buffer.writeln('설명: $description');
    buffer.writeln('대응: $response');
    buffer.writeln();
  }

  /// 체크리스트 항목을 추가한다.
  void _check(StringBuffer buffer, String label, bool done) {
    buffer.writeln('- [${done ? 'x' : ' '}] $label');
  }

  /// smoke 상태 한 줄 요약을 반환한다.
  String _smokeLine(SmokeTestRecord? record) {
    if (record == null) return 'pending (no record)';
    return '${record.platform} ${record.status.name} @ ${record.updatedAt.toIso8601String()}';
  }

  /// verification 기록 한 줄 요약을 반환한다.
  String _verificationLine(VerificationPassRecord? record) {
    if (record == null) return 'no record';
    final count = record.testCount != null ? ' (${record.testCount} tests)' : '';
    return 'PASS @ ${record.passedAt.toIso8601String()}$count commit=${record.verifiedSprintCommit ?? "n/a"}';
  }

  /// export 파일을 쓰고 감사 로그를 남긴다.
  Future<ReleaseMarkdownExportResult> _writeExport({
    required String filePrefix,
    required String markdown,
    required String auditTargetType,
  }) async {
    final stamp = _formatFileStamp(DateTime.now());
    final fileName = '${filePrefix}_$stamp.md';
    final relativePath = p.posix.join('.sac', 'exports', fileName);
    final exportDir = Directory(resolveWorkspacePath(workspaceRoot, p.posix.join('.sac', 'exports')));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final file = File(p.join(exportDir.path, fileName));
    await file.writeAsString(markdown);
    await _auditExport(relativePath, auditTargetType);
    return ReleaseMarkdownExportResult(
      relativePath: relativePath,
      absolutePath: file.path,
      markdown: markdown,
    );
  }

  /// export 감사 로그를 기록한다.
  Future<void> _auditExport(String relativePath, String targetType) async {
    await _db.insert('audit_logs', {
      'id': _uuid.v4(),
      'actor': 'user',
      'action': 'export',
      'target_type': targetType,
      'target_id': relativePath,
      'detail_json': '{"sensitive_body":false}',
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// target_type별 최신 export 시각을 조회한다.
  Future<DateTime?> _latestExportTime(String targetType) async {
    final rows = await _db.query(
      'audit_logs',
      where: "action = 'export' AND target_type = ?",
      whereArgs: [targetType],
      orderBy: 'occurred_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['occurred_at'] as String).toLocal();
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
