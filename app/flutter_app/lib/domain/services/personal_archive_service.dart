// personal_archive_service.dart — 개인 아카이브 서비스 인터페이스

import '../models/personal_archive.dart';

abstract class PersonalArchiveService {
  /// 개인 아카이브 항목 목록을 조회한다.
  Future<List<PersonalArchiveItem>> listItems({bool includeDeleted = false});

  /// 개인 아카이브 항목을 직접 생성한다.
  Future<PersonalArchiveItem> createManualItem(CreatePersonalArchiveItemInput input);

  /// 개인 아카이브 항목을 수정한다.
  Future<PersonalArchiveItem> updateItem(UpdatePersonalArchiveItemInput input);

  /// 개인 아카이브 항목을 삭제 상태로 변경한다.
  Future<void> deleteItem(String id);

  /// 승인된 후보에서 개인 아카이브 항목을 생성한다.
  Future<PersonalArchiveItem> createFromCandidate({
    required String itemType,
    required String title,
    required String content,
    String? sourceDocumentId,
    String? sourcePath,
    double? confidence,
  });
}
