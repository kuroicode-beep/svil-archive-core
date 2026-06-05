// SyncService: Markdown ↔ SQLite 동기화, 충돌 감지, revision 관리

import '../models/sync_state.dart';

abstract class SyncService {
  /// Workspace 전체 재스캔 (SQLite 재생성 가능)
  Future<void> fullRescan(String workspaceId);

  /// 파일 변경 이벤트 처리 (파일 watcher 연동)
  Future<void> onFileChanged(String relativePath);

  /// 특정 문서의 SyncState 조회
  Future<SyncState> getSyncState(String documentId);

  /// AI 수정 시도 전 revision 검증 (AI 덮어쓰기 방지)
  Future<bool> validateAiRevision(String documentId, int baseRevision);

  /// sync_journal에 이벤트 기록 (Phase 1: 기록 수준만)
  Future<void> appendJournal({
    required String documentId,
    required String actor,
    required String action,
    String? note,
  });
}
