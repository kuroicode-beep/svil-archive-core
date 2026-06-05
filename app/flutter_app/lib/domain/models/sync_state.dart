// SyncState: 문서와 DB 사이의 동기화 상태를 표현

enum SyncStatus { clean, dirty, userModified, aiPending, conflict, trashed }

class SyncState {
  final String documentId;
  final SyncStatus status;
  final DateTime? lastUserEditAt;
  final DateTime? lastAiEditAt;
  final String? lastActor;
  final int revision;
  final int baseRevision;

  const SyncState({
    required this.documentId,
    required this.status,
    this.lastUserEditAt,
    this.lastAiEditAt,
    this.lastActor,
    required this.revision,
    required this.baseRevision,
  });
}

class TrashItem {
  final String id;
  final String originalPath;
  final String documentId;
  final DateTime trashedAt;
  final String? trashedBy;

  const TrashItem({
    required this.id,
    required this.originalPath,
    required this.documentId,
    required this.trashedAt,
    this.trashedBy,
  });
}
