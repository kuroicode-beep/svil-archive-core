// relay_idempotency_service.dart — relay event idempotency key 저장·조회

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/database_service_impl.dart';
import '../db/sqlite_write_guard.dart';

/// content_hash + normalized_source_path + event_type 기반 중복 방지.
class RelayIdempotencyService {
  final DatabaseServiceImpl _databaseService;
  final SqliteWriteGuard _writeGuard;
  final Uuid _uuid = const Uuid();

  RelayIdempotencyService({
    required DatabaseServiceImpl databaseService,
    SqliteWriteGuard? writeGuard,
  })  : _databaseService = databaseService,
        _writeGuard = writeGuard ?? SqliteWriteGuard();

  Database get _db => _databaseService.requireDatabase();

  /// idempotency key를 생성한다.
  static String buildKey({
    required String contentHash,
    required String normalizedSourcePath,
    required String eventType,
  }) {
    return '$contentHash|$normalizedSourcePath|$eventType';
  }

  /// 이미 처리된 key인지 확인한다.
  Future<bool> isProcessed(String idempotencyKey) async {
    final rows = await _db.query(
      'relay_idempotency_keys',
      columns: ['idempotency_key'],
      where: 'idempotency_key = ?',
      whereArgs: [idempotencyKey],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// key를 등록한다. 이미 있으면 false.
  Future<bool> registerIfAbsent({
    required String idempotencyKey,
    required String eventType,
    String? resultRef,
  }) async {
    return _writeGuard.run(() async {
      final existing = await isProcessed(idempotencyKey);
      if (existing) return false;
      await _db.insert(
        'relay_idempotency_keys',
        {
          'id': _uuid.v4(),
          'idempotency_key': idempotencyKey,
          'event_type': eventType,
          'result_ref': resultRef,
          'processed_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final rows = await _db.query(
        'relay_idempotency_keys',
        where: 'idempotency_key = ?',
        whereArgs: [idempotencyKey],
        limit: 1,
      );
      return rows.isNotEmpty;
    });
  }
}
