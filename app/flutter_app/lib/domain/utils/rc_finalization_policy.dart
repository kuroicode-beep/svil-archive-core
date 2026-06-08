// rc_finalization_policy.dart — RC 보수 판정 정책 (Sprint 11)

import '../models/rc_finalization.dart';
import '../models/release_readiness.dart';
import '../models/smoke_test_record.dart';

/// RC 최종화 상태를 보수적으로 계산한다.
RcFinalizationStatus computeRcFinalizationStatus({
  required int failCount,
  required bool buildFailed,
  required SmokeTestStatus? macSmokeStatus,
  required SmokeTestStatus? winSmokeStatus,
  required bool verificationComplete,
  required bool verificationCommitMismatch,
}) {
  if (failCount > 0 || buildFailed) return RcFinalizationStatus.blocked;
  if (macSmokeStatus == SmokeTestStatus.failed || winSmokeStatus == SmokeTestStatus.failed) {
    return RcFinalizationStatus.blocked;
  }
  if (!verificationComplete) return RcFinalizationStatus.unknown;
  if (verificationCommitMismatch) return RcFinalizationStatus.warning;
  if (macSmokeStatus != SmokeTestStatus.passed || winSmokeStatus != SmokeTestStatus.passed) {
    return RcFinalizationStatus.warning;
  }
  return RcFinalizationStatus.ready;
}

/// RC 상태에 대응하는 UI 라벨을 반환한다.
String rcFinalizationStatusLabel(RcFinalizationStatus status) {
  switch (status) {
    case RcFinalizationStatus.ready:
      return 'RC 준비: 배포 후보 가능';
    case RcFinalizationStatus.warning:
      return 'RC 준비: 실기기 smoke 확인 필요';
    case RcFinalizationStatus.blocked:
      return 'RC 준비: 차단됨';
    case RcFinalizationStatus.unknown:
      return 'RC 준비: 자동 검증 기록 없음';
  }
}

/// readiness 항목에 build fail이 있는지 확인한다.
bool hasBuildFailure(List<ReadinessCheckItem> items) {
  return items.any(
    (i) => i.category == 'build' && i.status == ReadinessItemStatus.fail,
  );
}
