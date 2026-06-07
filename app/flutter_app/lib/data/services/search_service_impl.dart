// search_service_impl.dart — FTS5 키워드 검색 구현

import 'package:sqflite/sqflite.dart';

import '../../domain/services/search_service.dart';
import '../db/database_service_impl.dart';
import '../db/document_repository_impl.dart';

class SearchServiceImpl implements SearchService {
  final DatabaseServiceImpl _databaseService;
  final DocumentRepositoryImpl _repository;
  final String _workspaceId;

  SearchServiceImpl({
    required DatabaseServiceImpl databaseService,
    required DocumentRepositoryImpl repository,
    required String workspaceId,
  })  : _databaseService = databaseService,
        _repository = repository,
        _workspaceId = workspaceId;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<List<SearchResult>> search(SearchQuery query) async {
    return searchDocumentsByKeyword(
      query.text,
      limit: query.limit,
      offset: query.offset,
      category: query.type,
    );
  }

  /// FTS5 키워드 검색을 수행한다.
  Future<List<SearchResult>> searchDocumentsByKeyword(
    String query, {
    int limit = 20,
    int offset = 0,
    String? category,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final ftsQuery = _escapeFtsQuery(trimmed);
    final args = <Object?>[_workspaceId];
    var categoryClause = '';
    if (category != null && category.isNotEmpty) {
      categoryClause = 'AND d.category = ?';
      args.add(category);
    }
    args.addAll([ftsQuery, limit, offset]);

    final rows = await _db.rawQuery(
      '''
      SELECT d.id,
             d.relative_path,
             d.title,
             d.category,
             d.tags,
             d.content_hash,
             d.created_at,
             d.updated_at,
             d.is_deleted,
             s.revision AS sync_revision,
             s.status AS sync_status,
             snippet(document_fts, 3, '[', ']', '...', 48) AS snippet_text,
             bm25(document_fts) AS score
      FROM document_fts
      JOIN documents d ON d.id = document_fts.document_id
      LEFT JOIN sync_state s ON s.document_id = d.id
      WHERE d.workspace_id = ?
        AND d.is_deleted = 0
        $categoryClause
        AND document_fts MATCH ?
      ORDER BY score
      LIMIT ? OFFSET ?
      ''',
      args,
    );

    final seen = <String>{};
    final results = <SearchResult>[];
    for (final row in rows) {
      final id = row['id'] as String;
      if (seen.contains(id)) continue;
      seen.add(id);

      final metadata = _repository.mapRowPublic(row);
      results.add(SearchResult(
        document: metadata,
        highlight: row['snippet_text'] as String?,
        score: (row['score'] as num?)?.toDouble() ?? 0,
      ));
    }
    return results;
  }

  @override
  Future<List<SearchResult>> searchSimilar(String documentId, {int limit = 5}) async {
    throw UnimplementedError('Vector search is planned for Phase 3');
  }

  /// 특정 문서의 검색 스니펫을 반환한다.
  Future<String?> getSearchResultSnippet(String documentId, String query) async {
    final results = await searchDocumentsByKeyword(query, limit: 50);
    for (final result in results) {
      if (result.document.id == documentId) {
        return result.highlight;
      }
    }
    return null;
  }

  /// FTS MATCH용 쿼리 문자열을 이스케이프한다.
  String _escapeFtsQuery(String input) {
    final sanitized = input.replaceAll(RegExp(r'''["'*]'''), ' ').trim();
    final tokens = sanitized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    if (tokens.isEmpty) return '""';
    return tokens.map((t) => '"$t"*').join(' ');
  }
}
