// SearchService: FTS5 기반 전문 검색 + 향후 벡터 검색 확장 지점

import '../models/document.dart';

class SearchQuery {
  final String text;
  final String? type;
  final String? project;
  final String? author;
  final int limit;
  final int offset;

  const SearchQuery({
    required this.text,
    this.type,
    this.project,
    this.author,
    this.limit = 20,
    this.offset = 0,
  });
}

class SearchResult {
  final DocumentMetadata document;
  final String? highlight; // FTS5 스니펫
  final double score;

  const SearchResult({
    required this.document,
    this.highlight,
    required this.score,
  });
}

abstract class SearchService {
  /// FTS5 기반 전문 검색 (Phase 1)
  Future<List<SearchResult>> search(SearchQuery query);

  /// 벡터 기반 유사 문서 검색 (Phase 3 placeholder)
  Future<List<SearchResult>> searchSimilar(String documentId, {int limit = 5});
}
