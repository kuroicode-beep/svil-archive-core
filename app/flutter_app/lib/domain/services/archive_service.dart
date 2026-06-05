// ArchiveService: 문서 CRUD 핵심 서비스 — UI와 MCP가 공유하는 서비스 경계

import '../models/document.dart';

class CreateDocumentInput {
  final String title;
  final String? type;
  final String? project;
  final String? author;
  final String relativeDir; // Workspace 기준 상대 디렉토리
  final String initialContent;
  final List<String> tags;

  const CreateDocumentInput({
    required this.title,
    this.type,
    this.project,
    this.author,
    required this.relativeDir,
    this.initialContent = '',
    this.tags = const [],
  });
}

class UpdateDocumentInput {
  final String id;
  final String? title;
  final String? content;
  final String? author; // 수정 주체 (user / AI agent ID)
  final int baseRevision; // 충돌 방지용

  const UpdateDocumentInput({
    required this.id,
    this.title,
    this.content,
    this.author,
    required this.baseRevision,
  });
}

abstract class ArchiveService {
  /// 문서 목록 조회 (필터 없이 전체)
  Future<List<DocumentMetadata>> listDocuments();

  /// 단일 문서 메타데이터 조회
  Future<DocumentMetadata?> getDocument(String id);

  /// 문서 전체 (메타 + 본문) 조회
  Future<Document?> getDocumentWithContent(String id);

  /// 문서 생성
  Future<Document> createDocument(CreateDocumentInput input);

  /// 문서 수정 (AI 덮어쓰기 방지: baseRevision != currentRevision 시 거부)
  Future<Document> updateDocument(UpdateDocumentInput input);

  /// 문서 휴지통 이동
  Future<void> moveDocumentToTrash(String id);

  /// 휴지통에서 복원
  Future<Document> restoreDocument(String trashItemId);

  /// 문서 경로(상대) 변경
  Future<DocumentMetadata> moveDocument(String id, String newRelativePath);
}
