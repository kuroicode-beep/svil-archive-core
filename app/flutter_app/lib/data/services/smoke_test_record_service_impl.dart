// smoke_test_record_service_impl.dart — smoke test 기록 SQLite 구현

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/smoke_test_record.dart';
import '../../domain/services/smoke_test_record_service.dart';
import '../db/database_service_impl.dart';

class SmokeTestRecordServiceImpl implements SmokeTestRecordService {
  final DatabaseServiceImpl _databaseService;
  final Uuid _uuid = const Uuid();

  SmokeTestRecordServiceImpl({required DatabaseServiceImpl databaseService})
      : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<SmokeTestRecord> createRecord({
    required String platform,
    required String checklistName,
    SmokeTestStatus status = SmokeTestStatus.pending,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert('smoke_test_records', {
      'id': id,
      'platform': platform,
      'checklist_name': checklistName,
      'status': status.name,
      'notes': notes,
      'created_at': now,
      'updated_at': now,
    });
    return SmokeTestRecord(
      id: id,
      platform: platform,
      checklistName: checklistName,
      status: status,
      notes: notes,
      createdAt: DateTime.parse(now).toLocal(),
      updatedAt: DateTime.parse(now).toLocal(),
    );
  }

  @override
  Future<SmokeTestRecord> updateRecord({
    required String id,
    SmokeTestStatus? status,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final updates = <String, Object?>{'updated_at': now};
    if (status != null) updates['status'] = status.name;
    if (notes != null) updates['notes'] = notes;
    await _db.update('smoke_test_records', updates, where: 'id = ?', whereArgs: [id]);
    final rows = await _db.query('smoke_test_records', where: 'id = ?', whereArgs: [id]);
    return _mapRow(rows.first);
  }

  @override
  Future<SmokeTestRecord?> getLatestForPlatform(String platform) async {
    final rows = await _db.query(
      'smoke_test_records',
      where: 'platform = ?',
      whereArgs: [platform],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  @override
  Future<List<SmokeTestRecord>> listRecords() async {
    final rows = await _db.query('smoke_test_records', orderBy: 'updated_at DESC');
    return rows.map(_mapRow).toList();
  }

  /// DB row를 SmokeTestRecord로 변환한다.
  SmokeTestRecord _mapRow(Map<String, Object?> row) {
    return SmokeTestRecord(
      id: row['id'] as String,
      platform: row['platform'] as String,
      checklistName: row['checklist_name'] as String,
      status: SmokeTestStatus.values.firstWhere(
        (s) => s.name == (row['status'] as String? ?? 'pending'),
        orElse: () => SmokeTestStatus.pending,
      ),
      notes: row['notes'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }
}
