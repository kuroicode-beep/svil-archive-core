// sync_service_impl.dart — revision/hash/sync_state 관리 구현

import 'package:sqflite/sqflite.dart';

import '../../domain/models/sync_state.dart';
import '../../domain/services/sync_service.dart';
import '../db/database_service_impl.dart';
import 'sync_journal_writer.dart';

class SyncServiceImpl implements SyncService {
  final DatabaseServiceImpl _databaseService;
  final SyncJournalWriter _journalWriter;

  SyncServiceImpl({
    required DatabaseServiceImpl databaseService,
    required SyncJournalWriter journalWriter,
  })  : _databaseService = databaseService,
        _journalWriter = journalWriter;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<void> fullRescan(String workspaceId) async {
    // Sprint 15: orphan import는 DocumentImportService가 담당한다.
    throw UnimplementedError(
      'fullRescan is handled by DocumentImportService.scanWorkspaceOrphans',
    );
  }

  @override
  Future<void> onFileChanged(String relativePath) async {
    // Sprint 2 skeleton: dirty 상태만 표시
    final rows = await _db.query(
      'documents',
      columns: ['id'],
      where: 'relative_path = ?',
      whereArgs: [relativePath],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final documentId = rows.first['id'] as String;
    await _updateSyncState(
      documentId: documentId,
      status: SyncStatus.dirty,
      dirty: true,
    );
  }

  @override
  Future<SyncState> getSyncState(String documentId) async {
    final rows = await _db.query(
      'sync_state',
      where: 'document_id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return SyncState(
        documentId: documentId,
        status: SyncStatus.clean,
        revision: 1,
        baseRevision: 1,
      );
    }
    return _mapRow(rows.first);
  }

  @override
  Future<Map<String, SyncState>> listSyncStates() async {
    final rows = await _db.query('sync_state');
    return {
      for (final row in rows)
        row['document_id'] as String: _mapRow(row),
    };
  }

  @override
  Future<bool> validateAiRevision(String documentId, int baseRevision) async {
    final state = await getSyncState(documentId);
    return state.revision == baseRevision;
  }

  @override
  Future<void> appendJournal({
    required String documentId,
    required String actor,
    required String action,
    String? note,
  }) async {
    final state = await getSyncState(documentId);
    await _journalWriter.append(
      documentId: documentId,
      actor: actor,
      action: action,
      revision: state.revision,
      note: note,
    );
  }

  /// 문서 생성 시 초기 sync_state를 기록한다.
  Future<void> createInitialState({
    required String documentId,
    required String actor,
    required int revision,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert('sync_state', {
      'document_id': documentId,
      'revision': revision,
      'base_revision': revision,
      'status': SyncStatus.clean.name,
      'last_actor': actor,
      'last_user_edit_at': now,
      'dirty': 0,
      'conflict': 0,
      'locked': 0,
      'updated_at': now,
    });
    await appendJournal(
      documentId: documentId,
      actor: actor,
      action: 'create',
    );
  }

  /// 사용자 수정 후 sync_state를 갱신한다.
  Future<void> recordUserUpdate({
    required String documentId,
    required String actor,
    required int revision,
    required String contentHash,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _updateSyncState(
      documentId: documentId,
      status: SyncStatus.userModified,
      revision: revision,
      baseRevision: revision,
      lastActor: actor,
      lastUserEditAt: now,
      dirty: false,
    );
    await appendJournal(
      documentId: documentId,
      actor: actor,
      action: 'update',
      note: 'hash=$contentHash',
    );
  }

  /// sync_state row를 갱신한다.
  Future<void> _updateSyncState({
    required String documentId,
    required SyncStatus status,
    int? revision,
    int? baseRevision,
    String? lastActor,
    String? lastUserEditAt,
    bool? dirty,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final data = <String, Object?>{
      'status': status.name,
      'updated_at': now,
    };
    if (revision != null) data['revision'] = revision;
    if (baseRevision != null) data['base_revision'] = baseRevision;
    if (lastActor != null) data['last_actor'] = lastActor;
    if (lastUserEditAt != null) data['last_user_edit_at'] = lastUserEditAt;
    if (dirty != null) data['dirty'] = dirty ? 1 : 0;

    final updated = await _db.update(
      'sync_state',
      data,
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
    if (updated == 0) {
      await _db.insert('sync_state', {
        'document_id': documentId,
        'revision': revision ?? 1,
        'base_revision': baseRevision ?? revision ?? 1,
        'status': status.name,
        'last_actor': lastActor,
        'last_user_edit_at': lastUserEditAt,
        'dirty': (dirty ?? false) ? 1 : 0,
        'conflict': 0,
        'locked': 0,
        'updated_at': now,
      });
    }
  }

  /// DB row를 SyncState로 변환한다.
  SyncState _mapRow(Map<String, Object?> row) {
    final statusName = row['status'] as String? ?? 'clean';
    return SyncState(
      documentId: row['document_id'] as String,
      status: SyncStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => SyncStatus.clean,
      ),
      lastUserEditAt: row['last_user_edit_at'] != null
          ? DateTime.parse(row['last_user_edit_at'] as String).toLocal()
          : null,
      lastAiEditAt: row['last_ai_edit_at'] != null
          ? DateTime.parse(row['last_ai_edit_at'] as String).toLocal()
          : null,
      lastActor: row['last_actor'] as String?,
      revision: row['revision'] as int? ?? 1,
      baseRevision: row['base_revision'] as int? ?? 1,
    );
  }
}
