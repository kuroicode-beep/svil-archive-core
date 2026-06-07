// conflict_guard_service.dart — conflict guard 서비스 인터페이스

import '../models/work_queue.dart';

abstract class ConflictGuardService {
  /// 문서 쓰기 요청이 안전한지 검사한다.
  Future<ConflictGuardResult> validateWriteRequest(DocumentWriteRequest request);

  /// 파괴적 작업 요청이 안전한지 검사한다.
  Future<ConflictGuardResult> validateDestructiveRequest(DestructiveRequest request);
}
