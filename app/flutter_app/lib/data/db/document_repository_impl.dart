// document_repository_impl.dart — documents 테이블 영속성 구현

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/document.dart';
import '../../domain/services/document_repository.dart';
import 'database_service_impl.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  final DatabaseServiceImpl _databaseService;
  final String _workspaceId;

  DocumentRepositoryImpl({
    required DatabaseServiceImpl databaseService,
    required String workspaceId,
  })  : _databaseService = databaseService,
        _workspaceId = workspaceId;

  Database get _db => _databaseService.requireDatabase();

  static const String _selectWithRevision = '''
    SELECT d.*, s.revision AS sync_revision
    FROM documents d
    LEFT JOIN sync_state s ON d.id = s.document_id
  ''';

  @override
  Future<DocumentMetadata?> findById(String id) async {
    return _findByIdInternal(id, includeDeleted: false);
  }

  @override
  Future<DocumentMetadata?> findByIdIncludingDeleted(String id) async {
    return _findByIdInternal(id, includeDeleted: true);
  }

  /// ID 기반 문서 조회 내부 구현
  Future<DocumentMetadata?> _findByIdInternal(
    String id, {
    required bool includeDeleted,
  }) async {
    final deletedClause = includeDeleted ? '' : 'AND d.is_deleted = 0';
    final rows = await _db.rawQuery(
      '''
      $_selectWithRevision
      WHERE d.id = ? AND d.workspace_id = ? $deletedClause
      LIMIT 1
      ''',
      [id, _workspaceId],
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  @override
  Future<DocumentMetadata?> findByPath(String relativePath) async {
    final rows = await _db.rawQuery(
      '''
      $_selectWithRevision
      WHERE d.relative_path = ? AND d.workspace_id = ? AND d.is_deleted = 0
      LIMIT 1
      ''',
      [relativePath, _workspaceId],
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  @override
  Future<List<DocumentMetadata>> findAll({
    String? status,
    String? project,
    String? type,
  }) async {
    final where = <String>['d.workspace_id = ?', 'd.is_deleted = 0'];
    final args = <Object?>[_workspaceId];

    if (type != null) {
      where.add('d.category = ?');
      args.add(type);
    }

    final rows = await _db.rawQuery(
      '''
      $_selectWithRevision
      WHERE ${where.join(' AND ')}
      ORDER BY d.updated_at DESC
      ''',
      args,
    );
    return rows.map(_mapRow).toList();
  }

  @override
  Future<void> save(DocumentMetadata metadata) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final row = {
      'id': metadata.id,
      'workspace_id': _workspaceId,
      'relative_path': metadata.path,
      'title': metadata.title,
      'category': metadata.type,
      'tags': jsonEncode(metadata.tags),
      'content_hash': metadata.contentHash,
      'created_at': metadata.createdAt.toUtc().toIso8601String(),
      'updated_at': metadata.updatedAt.toUtc().toIso8601String(),
      'last_indexed_at': now,
      'is_deleted': metadata.status == DocumentStatus.trashed ? 1 : 0,
    };

    // REPLACE는 row 삭제 후 재삽입되어 sync_state FK CASCADE를 유발할 수 있다.
    if (await exists(metadata.id)) {
      await _db.update(
        'documents',
        row,
        where: 'id = ? AND workspace_id = ?',
        whereArgs: [metadata.id, _workspaceId],
      );
    } else {
      await _db.insert('documents', row);
    }
  }

  @override
  Future<void> delete(String id) async {
    await _db.update(
      'documents',
      {'is_deleted': 1},
      where: 'id = ? AND workspace_id = ?',
      whereArgs: [id, _workspaceId],
    );
  }

  @override
  Future<bool> exists(String id) async {
    final rows = await _db.query(
      'documents',
      columns: ['id'],
      where: 'id = ? AND workspace_id = ?',
      whereArgs: [id, _workspaceId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// 외부 서비스용 row → metadata 변환
  DocumentMetadata mapRowPublic(Map<String, Object?> row) => _mapRow(row);

  /// DB row를 DocumentMetadata로 변환한다.
  DocumentMetadata _mapRow(Map<String, Object?> row) {
    final tagsRaw = row['tags'] as String?;
    List<String> tags = const [];
    if (tagsRaw != null && tagsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(tagsRaw);
        if (decoded is List) {
          tags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        tags = const [];
      }
    }

    return DocumentMetadata(
      id: row['id'] as String,
      path: row['relative_path'] as String,
      title: row['title'] as String,
      type: row['category'] as String?,
      status: (row['is_deleted'] as int? ?? 0) == 1
          ? DocumentStatus.trashed
          : DocumentStatus.active,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      tags: tags,
      contentHash: row['content_hash'] as String,
      revision: row['sync_revision'] as int? ?? 1,
      sacSchema: '1',
    );
  }
}
