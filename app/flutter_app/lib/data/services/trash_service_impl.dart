// trash_service_impl.dart — 휴지통 이동/복구/완전삭제 구현

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/document.dart';
import '../../domain/models/sync_state.dart';
import '../../domain/services/document_file_store.dart';
import '../../domain/services/document_repository.dart';
import '../../domain/services/trash_service.dart';
import '../db/database_service_impl.dart';
import '../indexing/indexing_queue.dart';
import '../platform/path_adapter.dart';
import '../sync/sync_service_impl.dart';

class TrashServiceImpl implements TrashService {
  final DatabaseServiceImpl _databaseService;
  final DocumentRepository _repository;
  final DocumentFileStore _fileStore;
  final SyncServiceImpl _syncService;
  final IndexingQueue _indexingQueue;
  final String _workspaceRoot;
  final Uuid _uuid = const Uuid();

  TrashServiceImpl({
    required DatabaseServiceImpl databaseService,
    required DocumentRepository repository,
    required DocumentFileStore fileStore,
    required SyncServiceImpl syncService,
    required IndexingQueue indexingQueue,
    required String workspaceRoot,
  })  : _databaseService = databaseService,
        _repository = repository,
        _fileStore = fileStore,
        _syncService = syncService,
        _indexingQueue = indexingQueue,
        _workspaceRoot = workspaceRoot;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<TrashItem> moveToTrash(String documentId, {String? actor}) async {
    final metadata = await _repository.findById(documentId);
    if (metadata == null) {
      throw StateError('Document not found: $documentId');
    }

    final trashRelative = buildTrashRelativePath(documentId, metadata.path);
    await _fileStore.move(metadata.path, trashRelative);

    final now = DateTime.now().toUtc().toIso8601String();
    final trashId = _uuid.v4();
    await _db.insert('trash_items', {
      'id': trashId,
      'document_id': documentId,
      'original_path': metadata.path,
      'trashed_at': now,
      'trashed_by': actor ?? 'user',
    });

    final trashed = DocumentMetadata(
      id: metadata.id,
      path: trashRelative,
      title: metadata.title,
      author: metadata.author,
      project: metadata.project,
      type: metadata.type,
      status: DocumentStatus.trashed,
      createdAt: metadata.createdAt,
      updatedAt: DateTime.now(),
      tags: metadata.tags,
      summary: metadata.summary,
      contentHash: metadata.contentHash,
      revision: metadata.revision,
      sacSchema: metadata.sacSchema,
    );
    await _repository.save(trashed);

    await _db.update(
      'sync_state',
      {
        'status': SyncStatus.trashed.name,
        'updated_at': now,
        'last_actor': actor ?? 'user',
      },
      where: 'document_id = ?',
      whereArgs: [documentId],
    );

    await _syncService.appendJournal(
      documentId: documentId,
      actor: actor ?? 'user',
      action: 'trash',
    );
    _indexingQueue.queueDocument(documentId);

    return TrashItem(
      id: trashId,
      originalPath: metadata.path,
      documentId: documentId,
      trashedAt: DateTime.parse(now).toLocal(),
      trashedBy: actor,
    );
  }

  @override
  Future<String> restoreFromTrash(String trashItemId, {String? targetPath}) async {
    final rows = await _db.query(
      'trash_items',
      where: 'id = ?',
      whereArgs: [trashItemId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Trash item not found: $trashItemId');
    }
    final row = rows.first;
    final documentId = row['document_id'] as String;
    final originalPath = row['original_path'] as String;

    final metadata = await _repository.findByIdIncludingDeleted(documentId);
    if (metadata == null) {
      throw StateError('Document not found: $documentId');
    }

    var restorePath = targetPath ?? originalPath;
    assertSafeRelativePath(restorePath);
    resolveWorkspacePath(_workspaceRoot, restorePath);

    if (await _fileStore.exists(restorePath)) {
      final base = p.basenameWithoutExtension(restorePath);
      final ext = p.extension(restorePath);
      restorePath = p.posix.join(
        p.posix.dirname(restorePath),
        '${base}_restored$ext',
      );
      assertSafeRelativePath(restorePath);
      resolveWorkspacePath(_workspaceRoot, restorePath);
    }

    await _fileStore.move(metadata.path, restorePath);

    final restored = DocumentMetadata(
      id: metadata.id,
      path: restorePath,
      title: metadata.title,
      author: metadata.author,
      project: metadata.project,
      type: categoryFromRelativePath(restorePath),
      status: DocumentStatus.active,
      createdAt: metadata.createdAt,
      updatedAt: DateTime.now(),
      tags: metadata.tags,
      summary: metadata.summary,
      contentHash: metadata.contentHash,
      revision: metadata.revision,
      sacSchema: metadata.sacSchema,
    );
    await _repository.save(restored);

    final now = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      'sync_state',
      {
        'status': SyncStatus.dirty.name,
        'dirty': 1,
        'updated_at': now,
      },
      where: 'document_id = ?',
      whereArgs: [documentId],
    );

    await _db.delete('trash_items', where: 'id = ?', whereArgs: [trashItemId]);
    await _syncService.appendJournal(
      documentId: documentId,
      actor: 'user',
      action: 'restore',
    );
    _indexingQueue.queueDocument(documentId);
    return documentId;
  }

  @override
  Future<List<TrashItem>> listTrashItems() async {
    final rows = await _db.query('trash_items', orderBy: 'trashed_at DESC');
    return rows
        .map(
          (row) => TrashItem(
            id: row['id'] as String,
            originalPath: row['original_path'] as String,
            documentId: row['document_id'] as String,
            trashedAt: DateTime.parse(row['trashed_at'] as String).toLocal(),
            trashedBy: row['trashed_by'] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<void> permanentlyDelete(String trashItemId) async {
    // TODO(Sprint 6): destructive capability token 연결
    final rows = await _db.query(
      'trash_items',
      where: 'id = ?',
      whereArgs: [trashItemId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Trash item not found: $trashItemId');
    }
    final documentId = rows.first['document_id'] as String;
    final metadata = await _repository.findByIdIncludingDeleted(documentId);
    if (metadata != null) {
      await _fileStore.delete(metadata.path);
    }
    await _db.delete('trash_items', where: 'id = ?', whereArgs: [trashItemId]);
    await _repository.delete(documentId);
    await _db.delete('sync_state', where: 'document_id = ?', whereArgs: [documentId]);
    _indexingQueue.queueDocument(documentId);
  }

  @override
  Future<void> emptyTrash() async {
    final items = await listTrashItems();
    for (final item in items) {
      await permanentlyDelete(item.id);
    }
  }
}
