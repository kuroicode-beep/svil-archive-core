// release_approval_service.dart — Release approval 흐름 인터페이스

import '../models/rc_build_approval.dart';

abstract class ReleaseApprovalService {
  /// 현재 조건으로 approval 상태를 평가하고 기록한다.
  Future<ReleaseApprovalSummary> evaluateAndPersist();

  /// 최신 approval 요약을 반환한다.
  Future<ReleaseApprovalSummary?> getLatestSummary();

  /// 승인/거절 결정을 기록한다.
  Future<ReleaseApprovalSummary> recordDecision({
    required ReleaseApprovalStatus decision,
    String? notes,
    String? approvedBy,
  });
}
