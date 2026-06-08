// verification_pass_record_service_impl.dart — analyze/test/build 통과 기록 구현

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/rc_finalization.dart';
import '../../domain/services/verification_pass_record_service.dart';
import '../db/database_service_impl.dart';

/// 필수 자동 검증 check_type 목록.
const List<String> kRequiredVerificationCheckTypes = [
  'analyze',
  'test',
  'sidecar_build',
];

class VerificationPassRecordServiceImpl implements VerificationPassRecordService {
  final DatabaseServiceImpl _databaseService;
  final Uuid _uuid = const Uuid();

  VerificationPassRecordServiceImpl({required DatabaseServiceImpl databaseService})
      : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<VerificationPassRecord> recordPass({
    required String checkType,
    required String source,
    int? testCount,
    String? verifiedHeadCommit,
    String? verifiedSprintCommit,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final passedAt = DateTime.now().toUtc().toIso8601String();
    await _db.insert('verification_pass_records', {
      'id': id,
      'check_type': checkType,
      'source': source,
      'passed_at': passedAt,
      'test_count': testCount,
      'verified_head_commit': verifiedHeadCommit,
      'verified_sprint_commit': verifiedSprintCommit,
      'notes': notes,
    });
    return VerificationPassRecord(
      id: id,
      checkType: checkType,
      source: source,
      passedAt: DateTime.parse(passedAt).toLocal(),
      testCount: testCount,
      verifiedHeadCommit: verifiedHeadCommit,
      verifiedSprintCommit: verifiedSprintCommit,
      notes: notes,
    );
  }

  @override
  Future<VerificationPassRecord?> getLatestForType(String checkType) async {
    final rows = await _db.query(
      'verification_pass_records',
      where: 'check_type = ?',
      whereArgs: [checkType],
      orderBy: 'passed_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  @override
  Future<bool> hasCompleteVerificationSet() async {
    for (final type in kRequiredVerificationCheckTypes) {
      final latest = await getLatestForType(type);
      if (latest == null) return false;
    }
    return true;
  }

  @override
  Future<bool> hasCommitMismatch(String expectedSprintCommit) async {
    for (final type in kRequiredVerificationCheckTypes) {
      final latest = await getLatestForType(type);
      if (latest == null) return true;
      if (latest.commitMismatchFor(expectedSprintCommit)) return true;
    }
    return false;
  }

  /// DB row를 VerificationPassRecord로 변환한다.
  VerificationPassRecord _mapRow(Map<String, Object?> row) {
    return VerificationPassRecord(
      id: row['id'] as String,
      checkType: row['check_type'] as String,
      source: row['source'] as String,
      passedAt: DateTime.parse(row['passed_at'] as String).toLocal(),
      testCount: row['test_count'] as int?,
      verifiedHeadCommit: row['verified_head_commit'] as String?,
      verifiedSprintCommit: row['verified_sprint_commit'] as String?,
      notes: row['notes'] as String?,
    );
  }
}
