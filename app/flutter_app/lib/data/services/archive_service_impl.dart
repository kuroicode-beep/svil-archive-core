// archive_service_impl.dart — Markdown + SQLite 문서 CRUD 구현

import 'package:uuid/uuid.dart';

import '../../domain/models/document.dart';
import '../../domain/services/archive_service.dart';
import '../../domain/services/document_file_store.dart';
import '../../domain/services/document_repository.dart';
import '../file/content_hasher.dart';
import '../file/frontmatter_parser.dart';
import '../sync/sync_service_impl.dart';

class ArchiveServiceImpl implements ArchiveService {
  final DocumentRepository _repository;
  final DocumentFileStore _fileStore;
  final SyncServiceImpl _syncService;
  final String _workspaceId;
  final Uuid _uuid = const Uuid();

  ArchiveServiceImpl({
    required DocumentRepository repository,
    required DocumentFileStore fileStore,
    required SyncServiceImpl syncService,
    required String workspaceId,
  })  : _repository = repository,
        _fileStore = fileStore,
        _syncService = syncService,
        _workspaceId = workspaceId;

  @override
  Future<List<DocumentMetadata>> listDocuments() {
    return _repository.findAll();
  }

  @override
  Future<DocumentMetadata?> getDocument(String id) {
    return _repository.findById(id);
  }

  @override
  Future<Document?> getDocumentWithContent(String id) async {
    final metadata = await _repository.findById(id);
    if (metadata == null) return null;
    final raw = await _fileStore.readContent(metadata.path);
    final parsed = parseMarkdownWithFrontmatter(raw);
    return Document(
      metadata: metadata.copyWithRevision(parsed.lastKnownRevision),
      content: DocumentContent(
        documentId: id,
        rawMarkdown: parsed.body,
        loadedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Document> createDocument(CreateDocumentInput input) async {
    final id = _uuid.v4();
    final category = input.type ?? 'Dev';
    final safeTitle = _sanitizeFileName(input.title);
    final relativePath = 'documents/$category/$safeTitle.md';
    final revision = 1;
    final body = input.initialContent;

    final markdown = buildMarkdownWithFrontmatter(
      sacId: id,
      sacSchema: '1',
      body: body,
      revision: revision,
      sourceWorkspace: _workspaceId,
    );

    await _fileStore.writeContent(relativePath, markdown);

    final now = DateTime.now();
    final metadata = DocumentMetadata(
      id: id,
      path: relativePath,
      title: input.title,
      author: input.author,
      project: input.project,
      type: category,
      status: DocumentStatus.active,
      createdAt: now,
      updatedAt: now,
      tags: input.tags,
      contentHash: computeContentHash(body),
      revision: revision,
    );

    await _repository.save(metadata);
    await _syncService.createInitialState(
      documentId: id,
      actor: input.author ?? 'user',
      revision: revision,
    );

    return Document(
      metadata: metadata,
      content: DocumentContent(
        documentId: id,
        rawMarkdown: body,
        loadedAt: now,
      ),
    );
  }

  @override
  Future<Document> updateDocument(UpdateDocumentInput input) async {
    final existing = await _repository.findById(input.id);
    if (existing == null) {
      throw StateError('Document not found: ${input.id}');
    }

    final syncState = await _syncService.getSyncState(input.id);
    if (syncState.revision != input.baseRevision) {
      throw StateError(
        'Revision conflict: expected ${input.baseRevision}, current ${syncState.revision}',
      );
    }

    final title = input.title ?? existing.title;
    final body = input.content ??
        (await getDocumentWithContent(input.id))?.content?.rawMarkdown ??
        '';
    final newRevision = syncState.revision + 1;
    final actor = input.author ?? 'user';

    final markdown = buildMarkdownWithFrontmatter(
      sacId: existing.id,
      sacSchema: existing.sacSchema,
      body: body,
      revision: newRevision,
      sourceWorkspace: _workspaceId,
    );

    await _fileStore.writeContent(existing.path, markdown);

    final hash = computeContentHash(body);
    final updated = DocumentMetadata(
      id: existing.id,
      path: existing.path,
      title: title,
      author: existing.author,
      project: existing.project,
      type: existing.type,
      status: existing.status,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      tags: existing.tags,
      summary: existing.summary,
      contentHash: hash,
      revision: newRevision,
      sacSchema: existing.sacSchema,
    );

    await _repository.save(updated);
    await _syncService.recordUserUpdate(
      documentId: input.id,
      actor: actor,
      revision: newRevision,
      contentHash: hash,
    );

    return Document(
      metadata: updated,
      content: DocumentContent(
        documentId: input.id,
        rawMarkdown: body,
        loadedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> moveDocumentToTrash(String id) {
    throw UnimplementedError('moveDocumentToTrash is planned for Sprint 3');
  }

  @override
  Future<Document> restoreDocument(String trashItemId) {
    throw UnimplementedError('restoreDocument is planned for Sprint 3');
  }

  @override
  Future<DocumentMetadata> moveDocument(String id, String newRelativePath) {
    throw UnimplementedError('moveDocument is planned for Sprint 3');
  }

  /// 파일명에 사용할 수 없는 문자를 제거한다.
  String _sanitizeFileName(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'untitled' : cleaned;
  }
}

/// DocumentMetadata revision 필드 보조 extension
extension DocumentMetadataRevision on DocumentMetadata {
  /// revision 값을 갱신한 복사본을 반환한다.
  DocumentMetadata copyWithRevision(int revision) {
    return DocumentMetadata(
      id: id,
      path: path,
      title: title,
      author: author,
      project: project,
      type: type,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      tags: tags,
      summary: summary,
      contentHash: contentHash,
      revision: revision,
      sacSchema: sacSchema,
    );
  }
}
