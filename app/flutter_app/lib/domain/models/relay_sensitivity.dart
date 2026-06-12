// relay_sensitivity.dart — Relay export sensitivity label 및 redaction 결과

/// 문서 민감도 라벨.
enum SensitivityLabel {
  low,
  medium,
  high,
  mediumUnknown;

  static SensitivityLabel fromRaw(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'low':
        return SensitivityLabel.low;
      case 'medium':
        return SensitivityLabel.medium;
      case 'high':
        return SensitivityLabel.high;
      default:
        return SensitivityLabel.mediumUnknown;
    }
  }

  String get wireName {
    switch (this) {
      case SensitivityLabel.low:
        return 'low';
      case SensitivityLabel.medium:
        return 'medium';
      case SensitivityLabel.high:
        return 'high';
      case SensitivityLabel.mediumUnknown:
        return 'medium_unknown';
    }
  }
}

/// redaction 처리 상태.
enum RedactionStatus {
  none,
  redacted,
  blocked;

  String get wireName => name;
}

/// sensitivity + redaction 평가 결과.
class RelaySensitivityAssessment {
  final SensitivityLabel sensitivityLabel;
  final RedactionStatus redactionStatus;
  final List<String> redactionRuleHits;
  final bool exportAllowed;

  const RelaySensitivityAssessment({
    required this.sensitivityLabel,
    required this.redactionStatus,
    required this.redactionRuleHits,
    required this.exportAllowed,
  });

  Map<String, dynamic> toMetadataJson() => {
        'sensitivity_label': sensitivityLabel.wireName,
        'redaction_status': redactionStatus.wireName,
        'redaction_rule_hits': redactionRuleHits,
        'export_allowed': exportAllowed,
      };
}
