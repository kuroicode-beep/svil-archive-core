// journal_comment_service.dart — 일지 코멘트 서비스 인터페이스

import '../models/personal_archive.dart';

abstract class JournalCommentService {
  /// 일지 코멘트 목록을 조회한다.
  Future<List<JournalComment>> listComments();

  /// 일지 코멘트를 생성한다.
  Future<JournalComment> createComment(CreateJournalCommentInput input);

  /// 일지 코멘트를 수정한다.
  Future<JournalComment> updateComment(UpdateJournalCommentInput input);

  /// 일지 코멘트를 삭제한다.
  Future<void> deleteComment(String id);
}
