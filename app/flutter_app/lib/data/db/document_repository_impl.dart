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

  @override
  Future<DocumentMetadata?> findById(String id) async {
    final rows = await _db.query(
      'documents',
      where: 'id = ? AND workspace_id = ? AND is_deleted = 0',
      whereArgs: [id, _workspaceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  @override
  Future<DocumentMetadata?> findByPath(String relativePath) async {
    final rows = await _db.query(
      'documents',
      where: 'relative_path = ? AND workspace_id = ? AND is_deleted = 0',
      whereArgs: [relativePath, _workspaceId],
      limit: 1,
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
    final where = <String>['workspace_id = ?', 'is_deleted = 0'];
    final args = <Object?>[_workspaceId];

    if (type != null) {
      where.add('category = ?');
      args.add(type);
    }

    final rows = await _db.query(
      'documents',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'updated_at DESC',
    );
    return rows.map(_mapRow).toList();
  }

  @override
  Future<void> save(DocumentMetadata metadata) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert(
      'documents',
      {
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
      revision: 1,
      sacSchema: '1',
    );
  }
}
