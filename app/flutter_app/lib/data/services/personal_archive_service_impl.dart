// personal_archive_service_impl.dart — 개인 아카이브 SQLite 구현

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/personal_archive.dart';
import '../../domain/services/personal_archive_service.dart';
import '../db/database_service_impl.dart';

class PersonalArchiveServiceImpl implements PersonalArchiveService {
  final DatabaseServiceImpl _databaseService;
  final Uuid _uuid = const Uuid();

  PersonalArchiveServiceImpl({required DatabaseServiceImpl databaseService})
      : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<List<PersonalArchiveItem>> listItems({bool includeDeleted = false}) async {
    final where = includeDeleted ? null : "status != 'deleted'";
    final rows = await _db.query(
      'personal_archive_items',
      where: where,
      orderBy: 'updated_at DESC',
    );
    return rows.map(_mapItem).toList();
  }

  @override
  Future<PersonalArchiveItem> createManualItem(CreatePersonalArchiveItemInput input) async {
    return createFromCandidate(
      itemType: input.itemType,
      title: input.title,
      content: input.content,
    );
  }

  @override
  Future<PersonalArchiveItem> createFromCandidate({
    required String itemType,
    required String title,
    required String content,
    String? sourceDocumentId,
    String? sourcePath,
    double? confidence,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert('personal_archive_items', {
      'id': id,
      'item_type': itemType,
      'title': title,
      'content': content,
      'source_document_id': sourceDocumentId,
      'source_path': sourcePath,
      'confidence': confidence,
      'status': PersonalArchiveItemStatus.active.name,
      'created_at': now,
      'updated_at': now,
    });
    await _audit('create', id, itemType);
    return _mapItem({
      'id': id,
      'item_type': itemType,
      'title': title,
      'content': content,
      'source_document_id': sourceDocumentId,
      'source_path': sourcePath,
      'confidence': confidence,
      'status': PersonalArchiveItemStatus.active.name,
      'created_at': now,
      'updated_at': now,
    });
  }

  @override
  Future<PersonalArchiveItem> updateItem(UpdatePersonalArchiveItemInput input) async {
    final rows = await _db.query(
      'personal_archive_items',
      where: 'id = ?',
      whereArgs: [input.id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Personal archive item not found: ${input.id}');

    final existing = _mapItem(rows.first);
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = PersonalArchiveItem(
      id: existing.id,
      itemType: input.itemType ?? existing.itemType,
      title: input.title ?? existing.title,
      content: input.content ?? existing.content,
      sourceDocumentId: existing.sourceDocumentId,
      sourcePath: existing.sourcePath,
      confidence: existing.confidence,
      status: existing.status,
      createdAt: existing.createdAt,
      updatedAt: DateTime.parse(now).toLocal(),
    );

    await _db.update(
      'personal_archive_items',
      {
        'item_type': updated.itemType,
        'title': updated.title,
        'content': updated.content,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [input.id],
    );
    await _audit('update', input.id, updated.itemType);
    return updated;
  }

  @override
  Future<void> deleteItem(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      'personal_archive_items',
      {
        'status': PersonalArchiveItemStatus.deleted.name,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _audit('delete', id, 'personal_archive_item');
  }

  /// 감사 로그에 ID만 기록한다 (본문 미포함).
  Future<void> _audit(String action, String targetId, String targetType) async {
    await _db.insert('audit_logs', {
      'id': _uuid.v4(),
      'actor': 'user',
      'action': action,
      'target_type': targetType,
      'target_id': targetId,
      'detail_json': '{}',
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// DB row를 PersonalArchiveItem으로 변환한다.
  PersonalArchiveItem _mapItem(Map<String, Object?> row) {
    return PersonalArchiveItem(
      id: row['id'] as String,
      itemType: row['item_type'] as String,
      title: row['title'] as String,
      content: row['content'] as String,
      sourceDocumentId: row['source_document_id'] as String?,
      sourcePath: row['source_path'] as String?,
      confidence: (row['confidence'] as num?)?.toDouble(),
      status: PersonalArchiveItemStatus.values.firstWhere(
        (s) => s.name == (row['status'] as String? ?? 'active'),
        orElse: () => PersonalArchiveItemStatus.active,
      ),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }
}
