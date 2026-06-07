// safe_apply_service_impl.dart — Markdown safe apply 구현

import '../../domain/models/ticket_execution.dart';
import '../../domain/services/archive_service.dart';
import '../../domain/services/document_file_store.dart';
import '../../domain/services/document_repository.dart';
import '../../domain/services/safe_apply_service.dart';
import '../../domain/services/sync_service.dart';
import '../platform/path_adapter.dart';

class SafeApplyServiceImpl implements SafeApplyService {
  final ArchiveService _archiveService;
  final DocumentRepository _repository;
  final DocumentFileStore _fileStore;
  final SyncService _syncService;

  SafeApplyServiceImpl({
    required ArchiveService archiveService,
    required DocumentRepository repository,
    required DocumentFileStore fileStore,
    required SyncService syncService,
  })  : _archiveService = archiveService,
        _repository = repository,
        _fileStore = fileStore,
        _syncService = syncService;

  @override
  Future<SafeApplyResult> createDocument(SafeCreateDocumentRequest request) async {
    try {
      final relativePath = resolveCreateDocumentRelativePath(
        relativeDir: request.relativeDir,
        type: request.type,
        title: request.title,
      );
      final existing = await _repository.findByPath(relativePath);
      if (existing != null) {
        return const SafeApplyResult(
          success: false,
          targetPath: null,
          errorCode: 'file_exists',
          errorMessage: 'Target path already exists',
        );
      }
      if (await _fileStore.exists(relativePath)) {
        return const SafeApplyResult(
          success: false,
          targetPath: null,
          errorCode: 'orphan_file_exists',
          errorMessage: 'Orphan Markdown file exists at target path',
        );
      }

      final doc = await _archiveService.createDocument(
        CreateDocumentInput(
          title: request.title,
          type: request.type,
          relativeDir: request.relativeDir,
          initialContent: request.initialContent,
          author: request.actor,
        ),
      );
      return SafeApplyResult(
        success: true,
        documentId: doc.metadata.id,
        targetPath: doc.metadata.path,
        revisionBefore: 0,
        revisionAfter: doc.metadata.revision,
      );
    } on WorkspacePathException catch (e) {
      return SafeApplyResult(
        success: false,
        errorCode: 'path_blocked',
        errorMessage: e.message,
      );
    } catch (e) {
      return SafeApplyResult(
        success: false,
        errorCode: 'create_failed',
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<SafeApplyResult> updateDocument(SafeUpdateDocumentRequest request) async {
    try {
      final existing = await _archiveService.getDocument(request.documentId);
      if (existing == null) {
        return const SafeApplyResult(
          success: false,
          errorCode: 'not_found',
          errorMessage: 'Document not found',
        );
      }

      final syncBefore = await _syncService.getSyncState(request.documentId);
      final updated = await _archiveService.updateDocument(
        UpdateDocumentInput(
          id: request.documentId,
          title: request.title,
          content: request.content,
          author: request.actor,
          baseRevision: request.baseRevision,
        ),
      );
      return SafeApplyResult(
        success: true,
        documentId: updated.metadata.id,
        targetPath: updated.metadata.path,
        revisionBefore: syncBefore.revision,
        revisionAfter: updated.metadata.revision,
      );
    } catch (e) {
      return SafeApplyResult(
        success: false,
        documentId: request.documentId,
        errorCode: 'update_failed',
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<SafeApplyResult> moveDocumentToTrash(SafeTrashDocumentRequest request) async {
    try {
      final existing = await _archiveService.getDocument(request.documentId);
      if (existing == null) {
        return const SafeApplyResult(
          success: false,
          errorCode: 'not_found',
          errorMessage: 'Document not found',
        );
      }

      final syncBefore = await _syncService.getSyncState(request.documentId);
      await _archiveService.moveDocumentToTrash(request.documentId);
      return SafeApplyResult(
        success: true,
        documentId: request.documentId,
        targetPath: existing.path,
        revisionBefore: syncBefore.revision,
        revisionAfter: syncBefore.revision,
      );
    } catch (e) {
      return SafeApplyResult(
        success: false,
        documentId: request.documentId,
        errorCode: 'trash_failed',
        errorMessage: e.toString(),
      );
    }
  }
}
