// DocumentFileStore: Markdown 파일 I/O 계층 인터페이스
// 파일시스템 접근을 캡슐화하여 플랫폼 어댑터 교체 가능하게 함

import '../models/document.dart';

abstract class DocumentFileStore {
  /// Markdown 본문 읽기 (Workspace 기준 상대경로)
  Future<String> readContent(String relativePath);

  /// Markdown 파일 쓰기 (frontmatter 포함)
  Future<void> writeContent(String relativePath, String markdownWithFrontmatter);

  /// 파일 존재 여부 확인
  Future<bool> exists(String relativePath);

  /// 파일 이동 (rename 포함)
  Future<void> move(String fromPath, String toPath);

  /// 파일 삭제 (휴지통 이동이 아닌 즉시 삭제 — TrashService 경유 권장)
  Future<void> delete(String relativePath);

  /// 파일 해시 계산 (변경 감지용)
  Future<String> computeHash(String relativePath);

  /// 폴더 하위 Markdown 파일 목록 재귀 조회
  Future<List<String>> listMarkdownFiles(String relativeDirPath);

  /// frontmatter 파싱 (YAML → DocumentMetadata 초안)
  Future<DocumentMetadata> parseFrontmatter(String relativePath);
}
