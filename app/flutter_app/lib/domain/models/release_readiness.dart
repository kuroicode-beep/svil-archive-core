// release_readiness.dart — RC 준비 상태 도메인 모델

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
  final int passCount;
  final int warnCount;
  final int failCount;
  final List<ReadinessCheckItem> items;
  final DateTime checkedAt;

  const ReleaseReadinessSummary({
    required this.isReadyForRc,
    required this.passCount,
    required this.warnCount,
    required this.failCount,
    required this.items,
    required this.checkedAt,
  });

  /// RC를 막는 fail 항목만 반환한다.
  List<ReadinessCheckItem> get blockers =>
      items.where((i) => i.status == ReadinessItemStatus.fail).toList();
}
