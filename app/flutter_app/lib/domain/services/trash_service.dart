// TrashService: 휴지통 이동 / 복원 / 완전 삭제 책임
// DocumentFileStore와 DocumentRepository를 조합하여 휴지통 흐름을 처리

import '../models/sync_state.dart';

abstract class TrashService {
  /// 문서를 휴지통으로 이동 (.sac/trash/ 폴더로 파일 이동 + DB 상태 변경)
  Future<TrashItem> moveToTrash(String documentId, {String? actor});

  /// 휴지통에서 문서 복원 (원래 경로 또는 지정 경로로)
  Future<void> restoreFromTrash(String trashItemId, {String? targetPath});

  /// 휴지통 항목 목록 조회
  Future<List<TrashItem>> listTrashItems();

  /// 특정 휴지통 항목 완전 삭제 (파일 + DB 레코드 영구 제거)
  Future<void> permanentlyDelete(String trashItemId);

  /// 휴지통 전체 비우기
  Future<void> emptyTrash();
}
