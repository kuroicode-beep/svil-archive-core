// release_approval_policy.dart — Sprint 12 Release approval 보수 판정

import '../models/rc_build_approval.dart';
import '../models/rc_finalization.dart';
import '../models/smoke_test_record.dart';

/// Release approval 상태를 보수적으로 계산한다.
ReleaseApprovalStatus computeReleaseApprovalStatus({
  required RcFinalizationStatus rcFinalizationStatus,
  required bool verificationComplete,
  required bool releaseNotesExported,
  required bool knownIssuesExported,
  required bool tagReadinessExported,
  required SmokeTestStatus? macSmokeStatus,
  required SmokeTestStatus? winSmokeStatus,
  required bool integrityCritical,
  ReleaseApprovalStatus? stickyManualStatus,
}) {
  if (integrityCritical || rcFinalizationStatus == RcFinalizationStatus.blocked) {
    return ReleaseApprovalStatus.blocked;
  }
  if (stickyManualStatus == ReleaseApprovalStatus.rejected) {
    return ReleaseApprovalStatus.rejected;
  }
  if (macSmokeStatus == SmokeTestStatus.failed || winSmokeStatus == SmokeTestStatus.failed) {
    return ReleaseApprovalStatus.blocked;
  }
  final smokeBothPass =
      macSmokeStatus == SmokeTestStatus.passed && winSmokeStatus == SmokeTestStatus.passed;
  final exportsReady = releaseNotesExported && knownIssuesExported && tagReadinessExported;
  final autoReady = verificationComplete &&
      smokeBothPass &&
      exportsReady &&
      rcFinalizationStatus == RcFinalizationStatus.ready;

  if (stickyManualStatus == ReleaseApprovalStatus.approved && autoReady) {
    return ReleaseApprovalStatus.approved;
  }
  if (autoReady) return ReleaseApprovalStatus.readyForApproval;
  if (verificationComplete && !smokeBothPass) return ReleaseApprovalStatus.waitingSmoke;
  if (rcFinalizationStatus == RcFinalizationStatus.warning) {
    return ReleaseApprovalStatus.waitingSmoke;
  }
  return ReleaseApprovalStatus.draft;
}

/// Release approval 상태 UI 라벨을 반환한다.
String releaseApprovalStatusLabel(ReleaseApprovalStatus status) {
  switch (status) {
    case ReleaseApprovalStatus.draft:
      return 'RC 승인 초안: 조건 확인 필요';
    case ReleaseApprovalStatus.waitingSmoke:
      return 'RC 승인 대기: 실기기 smoke 확인 필요';
    case ReleaseApprovalStatus.readyForApproval:
      return 'RC 승인 가능: 자동 검증 및 smoke 기록 충족';
    case ReleaseApprovalStatus.approved:
      return 'RC 승인됨: v0.1.0-rc.1 tag 준비 완료';
    case ReleaseApprovalStatus.rejected:
      return 'RC 거절됨: 재검토 필요';
    case ReleaseApprovalStatus.blocked:
      return 'RC 차단: 실패 항목 확인 필요';
  }
}
