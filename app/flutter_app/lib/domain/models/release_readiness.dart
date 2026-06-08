// release_readiness.dart — RC 준비 상태 도메인 모델

import 'rc_finalization.dart';

enum ReadinessItemStatus { pass, warn, fail, unknown }

class ReadinessCheckItem {
  final String category;
  final String label;
  final ReadinessItemStatus status;
  final String? detail;

  const ReadinessCheckItem({
    required this.category,
    required this.label,
    required this.status,
    this.detail,
  });
}

class ReleaseReadinessSummary {
  final bool isReadyForRc;
  final RcFinalizationStatus rcFinalizationStatus;
  final String rcStatusLabel;
  final int passCount;
  final int warnCount;
  final int failCount;
  final List<ReadinessCheckItem> items;
  final DateTime checkedAt;
  final bool verificationCommitMismatch;

  const ReleaseReadinessSummary({
    required this.isReadyForRc,
    required this.rcFinalizationStatus,
    required this.rcStatusLabel,
    required this.passCount,
    required this.warnCount,
    required this.failCount,
    required this.items,
    required this.checkedAt,
    this.verificationCommitMismatch = false,
  });

  /// RC를 막는 fail 항목만 반환한다.
  List<ReadinessCheckItem> get blockers =>
      items.where((i) => i.status == ReadinessItemStatus.fail).toList();
}
