// conflict_guard_service_impl.dart — conflict guard SQLite 구현

import 'package:sqflite/sqflite.dart';

import '../../domain/models/sync_state.dart';
import '../../domain/models/work_queue.dart';
import '../../domain/services/conflict_guard_service.dart';
import '../db/database_service_impl.dart';
import '../platform/path_adapter.dart';

class ConflictGuardServiceImpl implements ConflictGuardService {
  final DatabaseServiceImpl _databaseService;
  final String workspaceRoot;

  ConflictGuardServiceImpl({
    required DatabaseServiceImpl databaseService,
    required this.workspaceRoot,
  }) : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<ConflictGuardResult> validateWriteRequest(DocumentWriteRequest request) async {
    final pathCheck = _validatePath(request.relativePath);
    if (pathCheck != null) return pathCheck;

    if (request.documentId != null) {
      final docCheck = await _validateDocument(request.documentId!);
      if (docCheck != null) return docCheck;

      if (request.baseRevision != null) {
        final revisionCheck = await _validateRevision(request.documentId!, request.baseRevision!);
        if (revisionCheck != null) return revisionCheck;
      }
    }

    return const ConflictGuardResult(
      action: ConflictGuardAction.requireApproval,
      message: 'Write request requires queue approval',
    );
  }

  @override
  Future<ConflictGuardResult> validateDestructiveRequest(DestructiveRequest request) async {
    final pathCheck = _validatePath(request.relativePath);
    if (pathCheck != null) return pathCheck;

    if (request.documentId != null) {
      final docCheck = await _validateDocument(request.documentId!);
      if (docCheck != null) return docCheck;
    }

    return const ConflictGuardResult(
      action: ConflictGuardAction.requireApproval,
      message: 'Destructive request requires queue approval',
    );
  }

  /// 상대경로가 workspace 내부인지 검사한다.
  ConflictGuardResult? _validatePath(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    try {
      resolveWorkspacePath(workspaceRoot, relativePath);
      return null;
    } on WorkspacePathException catch (e) {
      return ConflictGuardResult(
        action: ConflictGuardAction.block,
        message: 'Path blocked: ${e.message}',
      );
    }
  }

  /// 문서가 trashed/deleted 상태인지 검사한다.
  Future<ConflictGuardResult?> _validateDocument(String documentId) async {
    final rows = await _db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const ConflictGuardResult(
        action: ConflictGuardAction.block,
        message: 'Document not found',
      );
    }
    if ((rows.first['is_deleted'] as int? ?? 0) == 1) {
      return const ConflictGuardResult(
        action: ConflictGuardAction.block,
        message: 'Trashed document cannot be modified',
      );
    }
    final trashRows = await _db.query(
      'trash_items',
      where: 'document_id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    if (trashRows.isNotEmpty) {
      return const ConflictGuardResult(
        action: ConflictGuardAction.block,
        message: 'Trashed document cannot be modified',
      );
    }
    return null;
  }

  /// base revision이 최신인지 검사한다.
  Future<ConflictGuardResult?> _validateRevision(String documentId, int baseRevision) async {
    final rows = await _db.query(
      'sync_state',
      where: 'document_id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final statusName = row['status'] as String? ?? 'clean';
    if (statusName == SyncStatus.conflict.name || (row['conflict'] as int? ?? 0) == 1) {
      return const ConflictGuardResult(
        action: ConflictGuardAction.conflict,
        message: 'Document is in conflict state',
      );
    }

    final currentRevision = row['revision'] as int? ?? 1;
    if (baseRevision != currentRevision) {
      return ConflictGuardResult(
        action: ConflictGuardAction.conflict,
        message: 'Stale revision: expected $currentRevision got $baseRevision',
      );
    }

    final lastActor = row['last_actor'] as String?;
    if (lastActor == 'user' && statusName == SyncStatus.userModified.name) {
      return const ConflictGuardResult(
        action: ConflictGuardAction.conflict,
        message: 'Stale write after recent user modification',
      );
    }

    return null;
  }
}
