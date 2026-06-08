// verification_pass_record_service.dart — analyze/test/build 통과 기록 인터페이스

import '../models/rc_finalization.dart';

abstract class VerificationPassRecordService {
  /// 검증 통과 기록을 저장한다.
  Future<VerificationPassRecord> recordPass({
    required String checkType,
    required String source,
    int? testCount,
    String? verifiedHeadCommit,
    String? verifiedSprintCommit,
    String? notes,
  });

  /// checkType별 최신 통과 기록을 조회한다.
  Future<VerificationPassRecord?> getLatestForType(String checkType);

  /// 필수 자동 검증 기록이 모두 존재하는지 확인한다.
  Future<bool> hasCompleteVerificationSet();

  /// Sprint 구현 커밋과 불일치하는 기록이 있는지 확인한다.
  Future<bool> hasCommitMismatch(String expectedSprintCommit);
}
