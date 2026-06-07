// report_consistency_service_impl.dart — Sprint 보고서 커밋 해시 정합성 구현

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/models/report_consistency.dart';
import '../../domain/services/report_consistency_service.dart';
import '../db/database_service_impl.dart';

/// Sprint 보고서에 기대되는 커밋 해시 manifest.
const Map<String, String> kSprintReportCommitManifest = {
  'Sprint 07': '45d2b1f',
  'Sprint 08': '11b9454',
};

/// 구현 커밋으로 취급하는 frontmatter 키 suffix.
const Set<String> kImplementationCommitKeySuffixes = {
  'commit',
  'rework_commit',
  'rework2_commit',
  'implementation_commit',
  'final_commit',
};

/// base 커밋으로 제외하는 frontmatter 키 suffix.
const Set<String> kBaseCommitKeyMarkers = {
  'base_commit',
};

class ReportConsistencyServiceImpl implements ReportConsistencyService {
  final DatabaseServiceImpl _databaseService;
  final String? _reportDocsRoot;

  ReportConsistencyServiceImpl({
    required DatabaseServiceImpl databaseService,
    String? reportDocsRoot,
  })  : _databaseService = databaseService,
        _reportDocsRoot = reportDocsRoot;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<ReportConsistencySummary> checkReports() async {
    final mismatches = <ReportMismatch>[];
    mismatches.addAll(await _checkAppSettings());
    mismatches.addAll(await _checkLocalDocs());
    return ReportConsistencySummary(
      isConsistent: mismatches.isEmpty,
      mismatches: mismatches,
      checkedCount: kSprintReportCommitManifest.length,
    );
  }

  /// app_settings에 저장된 커밋 해시를 검사한다.
  Future<List<ReportMismatch>> _checkAppSettings() async {
    final mismatches = <ReportMismatch>[];
    for (final entry in kSprintReportCommitManifest.entries) {
      final key = 'report_commit_${entry.key.replaceAll(' ', '_').toLowerCase()}';
      final rows = await _db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      final actual = rows.isEmpty ? null : rows.first['value'] as String?;
      if (actual != null && actual != entry.value) {
        mismatches.add(
          ReportMismatch(
            sprintLabel: entry.key,
            expectedCommit: entry.value,
            actualCommit: actual,
            reason: 'app_settings $key does not match manifest',
          ),
        );
      }
    }
    return mismatches;
  }

  /// docs/reports 및 docs/handoff 마크다운의 커밋 해시를 검사한다.
  Future<List<ReportMismatch>> _checkLocalDocs() async {
    final docsRoot = _reportDocsRoot;
    if (docsRoot == null || docsRoot.isEmpty) return [];
    final rootDir = Directory(docsRoot);
    if (!await rootDir.exists()) return [];

    final mismatches = <ReportMismatch>[];
    for (final entry in kSprintReportCommitManifest.entries) {
      final sprintToken = entry.key.replaceAll(' ', '_');
      final sprintNum = entry.key.replaceAll('Sprint ', '');
      final files = await _collectSprintDocFiles(rootDir, sprintToken, sprintNum);
      if (files.isEmpty) continue;

      var foundExpected = false;
      for (final file in files) {
        final content = await File(file).readAsString();
        if (content.contains(entry.value)) {
          foundExpected = true;
        }
        for (final parsed in _parseFrontmatterCommits(content)) {
          if (_isBaseCommitKey(parsed.key)) continue;
          if (!_isImplementationCommitKey(parsed.key)) continue;
          if (parsed.hash == entry.value) {
            foundExpected = true;
            continue;
          }
          mismatches.add(
            ReportMismatch(
              sprintLabel: entry.key,
              expectedCommit: entry.value,
              actualCommit: parsed.hash,
              reason: '${p.basename(file)} frontmatter ${parsed.key} mismatch',
            ),
          );
        }
        for (final lineHash in _parseImplementationLineCommits(content)) {
          if (lineHash == entry.value) {
            foundExpected = true;
          } else {
            mismatches.add(
              ReportMismatch(
                sprintLabel: entry.key,
                expectedCommit: entry.value,
                actualCommit: lineHash,
                reason: '${p.basename(file)} implementation commit line mismatch',
              ),
            );
          }
        }
      }
      if (!foundExpected) {
        mismatches.add(
          ReportMismatch(
            sprintLabel: entry.key,
            expectedCommit: entry.value,
            reason: 'Expected commit not found in ${files.length} local doc(s)',
          ),
        );
      }
    }
    return mismatches;
  }

  /// Sprint 관련 docs 파일 경로를 수집한다.
  Future<List<String>> _collectSprintDocFiles(
    Directory docsRoot,
    String sprintToken,
    String sprintNum,
  ) async {
    final results = <String>[];
    for (final sub in ['reports', 'handoff']) {
      final dir = Directory(p.join(docsRoot.path, sub));
      if (!await dir.exists()) continue;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path).toLowerCase();
        if (!name.endsWith('.md')) continue;
        if (name.contains(sprintToken.toLowerCase()) ||
            name.contains('sprint$sprintNum') ||
            name.contains('sprint_$sprintNum')) {
          results.add(entity.path);
        }
      }
    }
    return results;
  }

  /// frontmatter에서 commit 해시를 파싱한다.
  List<({String key, String hash})> _parseFrontmatterCommits(String content) {
    final results = <({String key, String hash})>[];
    final lines = content.split('\n');
    if (lines.isEmpty || lines.first.trim() != '---') return results;
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line == '---') break;
      final match = RegExp(r'^([a-zA-Z0-9_]+):\s*"?([0-9a-f]{7,40})"?$').firstMatch(line);
      if (match != null) {
        results.add((key: match.group(1)!, hash: match.group(2)!));
      }
    }
    return results;
  }

  /// "구현 커밋" 라인에서 해시를 파싱한다.
  List<String> _parseImplementationLineCommits(String content) {
    final results = <String>[];
    final pattern = RegExp(
      r'구현\s*커밋[^`\r\n]*`([0-9a-f]{7,40})`',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(content)) {
      results.add(match.group(1)!);
    }
    return results;
  }

  /// base 커밋 키인지 확인한다.
  bool _isBaseCommitKey(String key) {
    final lower = key.toLowerCase();
    return kBaseCommitKeyMarkers.any(lower.contains);
  }

  /// 구현 커밋 키인지 확인한다.
  bool _isImplementationCommitKey(String key) {
    final lower = key.toLowerCase();
    if (_isBaseCommitKey(lower)) return false;
    return kImplementationCommitKeySuffixes.any((suffix) => lower.endsWith(suffix));
  }
}

/// 개발 환경에서 docs/ 경로를 자동 탐지한다.
String? resolveReportDocsRoot() {
  final candidates = <String>[
    p.normalize(p.join(Directory.current.path, '..', '..', 'docs')),
    p.normalize(p.join(Directory.current.path, 'docs')),
    p.normalize(p.join(Directory.current.path, '..', 'docs')),
  ];
  for (final candidate in candidates) {
    final dir = Directory(candidate);
    if (dir.existsSync() &&
        Directory(p.join(candidate, 'reports')).existsSync()) {
      return candidate;
    }
  }
  return null;
}
