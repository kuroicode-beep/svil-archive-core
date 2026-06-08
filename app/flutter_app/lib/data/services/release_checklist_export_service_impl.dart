// release_checklist_export_service_impl.dart — RC 체크리스트 Markdown export 구현

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/build_environment_check.dart';
import '../../domain/models/release_checklist_export.dart';
import '../../domain/models/release_readiness.dart';
import '../../domain/models/smoke_test_record.dart';
import '../../domain/services/build_environment_check_service.dart';
import '../../domain/services/release_checklist_export_service.dart';
import '../../domain/services/release_readiness_service.dart';
import '../../domain/services/smoke_test_record_service.dart';
import '../db/database_service_impl.dart';
import '../platform/path_adapter.dart';

class ReleaseChecklistExportServiceImpl implements ReleaseChecklistExportService {
  final DatabaseServiceImpl _databaseService;
  final String workspaceRoot;
  final ReleaseReadinessService _releaseReadinessService;
  final BuildEnvironmentCheckService _buildEnvironmentCheckService;
  final SmokeTestRecordService _smokeTestRecordService;
  final Uuid _uuid = const Uuid();

  ReleaseChecklistExportServiceImpl({
    required DatabaseServiceImpl databaseService,
    required this.workspaceRoot,
    required ReleaseReadinessService releaseReadinessService,
    required BuildEnvironmentCheckService buildEnvironmentCheckService,
    required SmokeTestRecordService smokeTestRecordService,
  })  : _databaseService = databaseService,
        _releaseReadinessService = releaseReadinessService,
        _buildEnvironmentCheckService = buildEnvironmentCheckService,
        _smokeTestRecordService = smokeTestRecordService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<ReleaseChecklistExportResult> exportToFile() async {
    final readiness = await _releaseReadinessService.evaluate();
    final buildChecks = await _buildEnvironmentCheckService.getLatestChecks();
    final smokeRecords = await _smokeTestRecordService.listRecords();
    final markdown = _composeMarkdown(
      readiness: readiness,
      buildChecks: buildChecks,
      smokeRecords: smokeRecords,
    );

    final now = DateTime.now();
    final stamp = _formatFileStamp(now);
    final relativePath = p.posix.join('.sac', 'exports', 'release_checklist_$stamp.md');
    final exportDir = Directory(resolveWorkspacePath(workspaceRoot, p.posix.join('.sac', 'exports')));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final file = File(p.join(exportDir.path, 'release_checklist_$stamp.md'));
    await file.writeAsString(markdown);
    await _auditExport(relativePath, readiness.items.length);

    return ReleaseChecklistExportResult(
      relativePath: relativePath,
      absolutePath: file.path,
      markdown: markdown,
      checkItemCount: readiness.items.length,
    );
  }

  /// RC 체크리스트 Markdown 본문을 생성한다.
  String _composeMarkdown({
    required ReleaseReadinessSummary readiness,
    required List<BuildEnvironmentCheck> buildChecks,
    required List<SmokeTestRecord> smokeRecords,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# SAC Release Checklist');
    buffer.writeln();
    buffer.writeln('- generated_at: ${readiness.checkedAt.toIso8601String()}');
    buffer.writeln('- rc_ready: ${readiness.isReadyForRc}');
    buffer.writeln('- pass: ${readiness.passCount} / warn: ${readiness.warnCount} / fail: ${readiness.failCount}');
    buffer.writeln();
    buffer.writeln('## RC Readiness');
    buffer.writeln();
    buffer.writeln('| category | label | status | detail |');
    buffer.writeln('|----------|-------|--------|--------|');
    for (final item in readiness.items) {
      buffer.writeln(
        '| ${item.category} | ${item.label} | ${item.status.name} | ${item.detail ?? ''} |',
      );
    }
    buffer.writeln();
    buffer.writeln('## Build Environment');
    buffer.writeln();
    for (final check in buildChecks) {
      buffer.writeln('- ${check.checkName}: ${check.status.name} — ${check.message}');
    }
    buffer.writeln();
    buffer.writeln('## Smoke Test Records');
    buffer.writeln();
    if (smokeRecords.isEmpty) {
      buffer.writeln('- (no records)');
    } else {
      for (final record in smokeRecords) {
        buffer.writeln(
          '- ${record.platform} / ${record.checklistName}: ${record.status.name} (${record.updatedAt.toIso8601String()})',
        );
      }
    }
    buffer.writeln();
    buffer.writeln('## macOS Checklist');
    for (final item in kDefaultMacOsSmokeChecklist) {
      buffer.writeln('- [ ] $item');
    }
    buffer.writeln();
    buffer.writeln('## Windows Checklist');
    for (final item in kDefaultWindowsSmokeChecklist) {
      buffer.writeln('- [ ] $item');
    }
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('*SAC Sprint 10 — RC / Smoke / Packaging Readiness*');
    return buffer.toString();
  }

  /// export 감사 로그를 기록한다.
  Future<void> _auditExport(String relativePath, int itemCount) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert('audit_logs', {
      'id': _uuid.v4(),
      'actor': 'user',
      'action': 'export',
      'target_type': 'release_checklist',
      'target_id': relativePath,
      'detail_json': '{"item_count":$itemCount}',
      'occurred_at': now,
    });
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
