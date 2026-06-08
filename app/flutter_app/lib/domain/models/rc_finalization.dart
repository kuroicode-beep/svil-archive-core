// rc_finalization.dart — Sprint 11 RC 최종화 도메인 모델

import 'release_readiness.dart';
import 'smoke_test_record.dart';

/// RC 최종화 보수 판정 상태.
enum RcFinalizationStatus { ready, warning, blocked, unknown }

/// 자동/수동 검증 통과 기록.
class VerificationPassRecord {
  final String id;
  final String checkType;
  final String source;
  final DateTime passedAt;
  final int? testCount;
  final String? verifiedHeadCommit;
  final String? verifiedSprintCommit;
  final String? notes;

  const VerificationPassRecord({
    required this.id,
    required this.checkType,
    required this.source,
    required this.passedAt,
    this.testCount,
    this.verifiedHeadCommit,
    this.verifiedSprintCommit,
    this.notes,
  });

  /// Sprint 구현 커밋과 기록이 불일치하는지 확인한다.
  bool commitMismatchFor(String expectedSprintCommit) {
    if (verifiedSprintCommit == null || verifiedSprintCommit!.isEmpty) return true;
    return verifiedSprintCommit != expectedSprintCommit;
  }
}

/// RC export 생성 여부 요약.
class ReleaseExportStatus {
  final bool releaseNotesExported;
  final bool knownIssuesExported;
  final bool tagReadinessExported;
  final DateTime? releaseNotesExportedAt;
  final DateTime? knownIssuesExportedAt;
  final DateTime? tagReadinessExportedAt;

  const ReleaseExportStatus({
    required this.releaseNotesExported,
    required this.knownIssuesExported,
    required this.tagReadinessExported,
    this.releaseNotesExportedAt,
    this.knownIssuesExportedAt,
    this.tagReadinessExportedAt,
  });
}

/// Dashboard용 RC 최종화 요약.
class RcFinalizationSummary {
  final RcFinalizationStatus status;
  final String statusLabel;
  final ReleaseReadinessSummary readiness;
  final ReleaseExportStatus exportStatus;
  final SmokeTestStatus? macSmokeStatus;
  final SmokeTestStatus? windowsSmokeStatus;
  final String suggestedTag;

  const RcFinalizationSummary({
    required this.status,
    required this.statusLabel,
    required this.readiness,
    required this.exportStatus,
    this.macSmokeStatus,
    this.windowsSmokeStatus,
    this.suggestedTag = 'v0.1.0-rc.1',
  });
}

/// Markdown export 공통 결과.
class ReleaseMarkdownExportResult {
  final String relativePath;
  final String absolutePath;
  final String markdown;

  const ReleaseMarkdownExportResult({
    required this.relativePath,
    required this.absolutePath,
    required this.markdown,
  });
}
