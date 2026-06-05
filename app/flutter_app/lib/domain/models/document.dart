// Document: Markdown 문서 한 개를 표현하는 도메인 모델

enum DocumentStatus { active, archived, trashed }

class DocumentMetadata {
  final String id;           // sac_id (UUID)
  final String path;         // Workspace 기준 상대경로
  final String title;
  final String? author;
  final String? project;
  final String? type;
  final DocumentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final String? summary;
  final String contentHash;
  final int revision;
  final String sacSchema;

  const DocumentMetadata({
    required this.id,
    required this.path,
    required this.title,
    this.author,
    this.project,
    this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.summary,
    required this.contentHash,
    required this.revision,
    this.sacSchema = '1',
  });
}

class DocumentContent {
  final String documentId;
  final String rawMarkdown;
  final DateTime loadedAt;

  const DocumentContent({
    required this.documentId,
    required this.rawMarkdown,
    required this.loadedAt,
  });
}

class Document {
  final DocumentMetadata metadata;
  final DocumentContent? content;

  const Document({required this.metadata, this.content});
}
