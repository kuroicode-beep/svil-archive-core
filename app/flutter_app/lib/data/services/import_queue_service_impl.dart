// import_queue_service_impl.dart — Import Queue SQLite 구현 (Sprint 16)

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/import_queue_item.dart';
import '../../domain/services/import_queue_service.dart';
import '../db/database_service_impl.dart';

class ImportQueueServiceImpl implements ImportQueueService {
  final DatabaseServiceImpl _databaseService;
  final Uuid _uuid = const Uuid();

  ImportQueueServiceImpl({required DatabaseServiceImpl databaseService})
      : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<ImportQueueItem?> enqueueDetected({
    required String sourceAbsolutePath,
    required String originalFileName,
    required String? matchedPrefix,
    required String targetFileName,
    required String sourceAi,
    required int fileSize,
  }) async {
    final existing = await _db.query(
      'import_queue',
      where: 'source_absolute_path = ?',
      whereArgs: [sourceAbsolutePath],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      // 이미 처리(또는 감지)된 파일은 중복 등록하지 않는다.
      return null;
    }
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _db.insert(
      'import_queue',
      {
        'id': id,
        'original_file_name': originalFileName,
        'source_absolute_path': sourceAbsolutePath,
        'matched_prefix': matchedPrefix,
        'target_file_name': targetFileName,
        'source_ai': sourceAi,
        'file_size': fileSize,
        'status': ImportQueueStatus.detected.name,
        'detected_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return findById(id);
  }

  @override
  Future<List<ImportQueueItem>> listItems({List<ImportQueueStatus>? statuses}) async {
    final List<Map<String, Object?>> rows;
    if (statuses == null || statuses.isEmpty) {
      rows = await _db.query('import_queue', orderBy: 'detected_at DESC');
    } else {
      final placeholders = List.filled(statuses.length, '?').join(',');
      rows = await _db.query(
        'import_queue',
        where: 'status IN ($placeholders)',
        whereArgs: statuses.map((s) => s.name).toList(),
        orderBy: 'detected_at DESC',
      );
    }
    return rows.map(ImportQueueItem.fromRow).toList();
  }

  @override
  Future<ImportQueueItem?> findById(String id) async {
    final rows = await _db.query(
      'import_queue',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ImportQueueItem.fromRow(rows.first);
  }

  @override
  Future<void> updateStatus(
    String id,
    ImportQueueStatus status, {
    String? importedDocumentId,
    String? errorMessage,
  }) async {
    final values = <String, Object?>{
      'status': status.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (importedDocumentId != null) {
      values['imported_document_id'] = importedDocumentId;
    }
    values['error_message'] = errorMessage;
    await _db.update('import_queue', values, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> countByStatus(ImportQueueStatus status) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM import_queue WHERE status = ?',
      [status.name],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  @override
  Future<void> removeItem(String id) async {
    await _db.delete('import_queue', where: 'id = ?', whereArgs: [id]);
  }
}
