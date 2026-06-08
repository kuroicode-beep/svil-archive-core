// document_indexer.dart — document_chunks 및 FTS5 인덱스 갱신

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/document.dart';
import '../../domain/services/document_file_store.dart';
import '../../domain/services/document_repository.dart';
import '../db/database_service_impl.dart';
import '../file/content_hasher.dart';
import '../file/frontmatter_parser.dart';
import 'document_chunker.dart';

class DocumentIndexer {
  final DatabaseServiceImpl _databaseService;
  final DocumentRepository _repository;
  final DocumentFileStore _fileStore;
  final String _workspaceId;
  final Uuid _uuid = const Uuid();

  DocumentIndexer({
    required DatabaseServiceImpl databaseService,
    required DocumentRepository repository,
    required DocumentFileStore fileStore,
    required String workspaceId,
  })  : _databaseService = databaseService,
        _repository = repository,
        _fileStore = fileStore,
        _workspaceId = workspaceId;

  Database get _db => _databaseService.requireDatabase();

  /// 단일 문서를 재인덱싱한다.
  Future<void> reindexDocument(String documentId) async {
    final metadata = await _repository.findById(documentId);
    if (metadata == null || metadata.status == DocumentStatus.trashed) {
      await _removeFromIndex(documentId);
      return;
    }

    String body;
    try {
      final raw = await _fileStore.readContent(metadata.path);
      try {
        body = parseMarkdownWithFrontmatter(raw).body;
      } on FrontmatterParseException {
        // frontmatter가 없는 문서(외부 import/orphan)는 원문 전체를 인덱싱한다.
        body = raw;
      }
    } catch (_) {
      return;
    }

    final chunks = chunkMarkdownBody(body);
    final now = DateTime.now().toUtc().toIso8601String();
    final tags = metadata.tags.join(' ');

    await _db.transaction((txn) async {
      await txn.delete('document_chunks', where: 'document_id = ?', whereArgs: [documentId]);
      await txn.delete('document_fts', where: 'document_id = ?', whereArgs: [documentId]);

      for (final chunk in chunks) {
        final chunkId = _uuid.v4();
        final hash = computeContentHash(chunk.content);
        await txn.insert('document_chunks', {
          'id': chunkId,
          'document_id': documentId,
          'chunk_index': chunk.chunkIndex,
          'heading_path': chunk.heading,
          'content': chunk.content,
          'content_hash': hash,
          'token_count': chunk.content.length,
          'created_at': now,
          'updated_at': now,
        });
        await txn.insert('document_fts', {
          'document_id': documentId,
          'title': metadata.title,
          'heading': chunk.heading,
          'content': chunk.content,
          'tags': tags,
          'category': metadata.type ?? '',
        });
      }

      await txn.update(
        'documents',
        {'last_indexed_at': now},
        where: 'id = ? AND workspace_id = ?',
        whereArgs: [documentId, _workspaceId],
      );
    });
  }

  /// workspace 전체 문서를 재인덱싱한다.
  Future<void> reindexWorkspace() async {
    final docs = await _repository.findAll();
    for (final doc in docs) {
      await reindexDocument(doc.id);
    }
  }

  /// 문서 인덱스를 제거한다.
  Future<void> _removeFromIndex(String documentId) async {
    await _db.transaction((txn) async {
      await txn.delete('document_chunks', where: 'document_id = ?', whereArgs: [documentId]);
      await txn.delete('document_fts', where: 'document_id = ?', whereArgs: [documentId]);
    });
  }

  /// FTS 인덱스를 전체 재구성한다.
  Future<void> rebuildFtsIndex() async {
    await _db.execute("INSERT INTO document_fts(document_fts) VALUES('rebuild')");
  }
}
