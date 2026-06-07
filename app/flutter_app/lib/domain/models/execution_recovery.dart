// execution_recovery.dart — 실행 티켓 복구 도메인 모델

enum RecoveryEligibility { eligible, notEligible, requiresReview }

class RecoveryAssessment {
  final String ticketId;
  final RecoveryEligibility eligibility;
  final String summary;
  final List<String> suggestedActions;
  final bool dryRunAvailable;

  const RecoveryAssessment({
    required this.ticketId,
    required this.eligibility,
    required this.summary,
    required this.suggestedActions,
    required this.dryRunAvailable,
  });
}
