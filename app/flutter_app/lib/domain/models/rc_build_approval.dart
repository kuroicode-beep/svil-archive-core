// rc_build_approval.dart — Sprint 12 RC build / approval / tag readiness 모델

import 'smoke_test_record.dart';

/// RC 빌드 유형.
enum RcBuildType { debug, release, rc }

/// RC 빌드 산출물 상태.
enum RcBuildArtifactStatus { pending, pass, fail }

/// Release approval 상태.
enum ReleaseApprovalStatus {
  draft,
  waitingSmoke,
  readyForApproval,
  approved,
  rejected,
  blocked,
}

/// RC build artifact 기록.
class RcBuildArtifact {
  final String id;
  final String platform;
  final RcBuildType buildType;
  final String artifactPathMasked;
  final String commitHash;
  final RcBuildArtifactStatus status;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final String? notes;

  const RcBuildArtifact({
    required this.id,
    required this.platform,
    required this.buildType,
    required this.artifactPathMasked,
    required this.commitHash,
    required this.status,
    required this.createdAt,
    this.verifiedAt,
    this.notes,
  });
}

/// 플랫폼별 smoke approval 요약.
class SmokeApprovalSummary {
  final SmokeTestStatus? macStatus;
  final SmokeTestStatus? windowsStatus;
  final bool macRecorded;
  final bool windowsRecorded;
  final bool bothPassed;

  const SmokeApprovalSummary({
    this.macStatus,
    this.windowsStatus,
    required this.macRecorded,
    required this.windowsRecorded,
    required this.bothPassed,
  });
}

/// Release approval 요약.
class ReleaseApprovalSummary {
  final String id;
  final ReleaseApprovalStatus status;
  final String statusLabel;
  final String rcCommitHash;
  final String? notes;
  final String? approvedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReleaseApprovalSummary({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.rcCommitHash,
    this.notes,
    this.approvedBy,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// RC tag readiness 단일 체크 항목.
class RcTagReadinessCheckItem {
  final String id;
  final String checkLabel;
  final bool passed;
  final String? detail;
  final DateTime checkedAt;

  const RcTagReadinessCheckItem({
    required this.id,
    required this.checkLabel,
    required this.passed,
    this.detail,
    required this.checkedAt,
  });
}

/// RC tag readiness 실행 결과.
class RcTagReadinessSummary {
  final String runId;
  final List<RcTagReadinessCheckItem> items;
  final bool allPassed;
  final String suggestedTag;
  final DateTime checkedAt;

  const RcTagReadinessSummary({
    required this.runId,
    required this.items,
    required this.allPassed,
    this.suggestedTag = 'v0.1.0-rc.1',
    required this.checkedAt,
  });
}

/// Dashboard용 RC 최종 상태 요약.
class RcFinalStatusSummary {
  final ReleaseApprovalStatus approvalStatus;
  final String approvalLabel;
  final int buildArtifactCount;
  final bool tagReadinessReady;
  final bool finalBundleGenerated;
  final SmokeTestStatus? macSmokeStatus;
  final SmokeTestStatus? windowsSmokeStatus;
  final String rcCommitHash;

  const RcFinalStatusSummary({
    required this.approvalStatus,
    required this.approvalLabel,
    required this.buildArtifactCount,
    required this.tagReadinessReady,
    required this.finalBundleGenerated,
    this.macSmokeStatus,
    this.windowsSmokeStatus,
    required this.rcCommitHash,
  });
}

/// Final release bundle export 결과.
class FinalReleaseBundleResult {
  final String relativePath;
  final String absolutePath;
  final String markdown;

  const FinalReleaseBundleResult({
    required this.relativePath,
    required this.absolutePath,
    required this.markdown,
  });
}
