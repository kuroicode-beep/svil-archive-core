// DocumentRepository: SQLite 기반 문서 메타데이터 영속성 계층 인터페이스
// DB 계층과 도메인 계층의 경계를 명확히 분리

import '../models/document.dart';

abstract class DocumentRepository {
  /// ID로 문서 메타데이터 조회
  Future<DocumentMetadata?> findById(String id);

  /// ID로 문서 메타데이터 조회 (휴지통 포함)
  Future<DocumentMetadata?> findByIdIncludingDeleted(String id);

  /// 상대경로로 문서 메타데이터 조회
  Future<DocumentMetadata?> findByPath(String relativePath);

  /// 전체 문서 목록 조회 (status 필터 포함)
  Future<List<DocumentMetadata>> findAll({String? status, String? project, String? type});

  /// 문서 메타데이터 저장 (신규 or 갱신)
  Future<void> save(DocumentMetadata metadata);

  /// 문서 메타데이터 삭제 (DB에서만 — 파일 삭제 아님)
  Future<void> delete(String id);

  /// 존재 여부 확인
  Future<bool> exists(String id);
}
