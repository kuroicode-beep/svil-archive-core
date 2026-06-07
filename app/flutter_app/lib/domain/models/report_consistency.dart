// report_consistency.dart — Sprint 보고서 커밋 해시 정합성 모델

class ReportMismatch {
  final String sprintLabel;
  final String expectedCommit;
  final String? actualCommit;
  final String reason;

  const ReportMismatch({
    required this.sprintLabel,
    required this.expectedCommit,
    this.actualCommit,
    required this.reason,
  });
}

class ReportConsistencySummary {
  final bool isConsistent;
  final List<ReportMismatch> mismatches;
  final int checkedCount;

  const ReportConsistencySummary({
    required this.isConsistent,
    required this.mismatches,
    required this.checkedCount,
  });
}
