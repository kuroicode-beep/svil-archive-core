// relay_sensitivity_service.dart — sensitivity label 및 regex redaction

import '../../domain/models/relay_sensitivity.dart';
import '../../domain/utils/path_masking.dart';

/// Relay export용 민감정보 평가·redaction 서비스.
class RelaySensitivityService {
  static final List<RegExp> _redactionPatterns = [
    RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
    RegExp(r'\b\d{2,3}[-.\s]?\d{3,4}[-.\s]?\d{4}\b'),
    RegExp(r'(api[_-]?key|secret|password|bearer\s+[A-Za-z0-9._-]+)', caseSensitive: false),
    RegExp(r'(sk-[A-Za-z0-9]{10,}|ghp_[A-Za-z0-9]{20,})', caseSensitive: false),
    RegExp(r'(-----BEGIN (?:RSA )?PRIVATE KEY-----)', caseSensitive: false),
    RegExp(r'(postgres(?:ql)?://\S+|mysql://\S+)', caseSensitive: false),
    RegExp(r'[A-Za-z]:\\Users\\[^\\]+', caseSensitive: false),
    RegExp(r'/Users/[^/\s]+'),
    RegExp(r'(account recovery|reset password|2fa code)', caseSensitive: false),
  ];

  /// 문서 본문을 평가하고 redaction을 적용한다.
  RelaySensitivityAssessment assessAndRedact({
    String? explicitLabel,
    required String content,
    bool forPreview = true,
  }) {
    final label = explicitLabel == null || explicitLabel.trim().isEmpty
        ? SensitivityLabel.mediumUnknown
        : SensitivityLabel.fromRaw(explicitLabel);

    if (label == SensitivityLabel.high) {
      return RelaySensitivityAssessment(
        sensitivityLabel: label,
        redactionStatus: RedactionStatus.blocked,
        redactionRuleHits: const ['high_sensitivity_block'],
        exportAllowed: false,
      );
    }

    final hits = <String>[];
    for (var i = 0; i < _redactionPatterns.length; i++) {
      if (_redactionPatterns[i].hasMatch(content)) {
        hits.add('rule_$i');
      }
    }
    if (exportContainsSensitivePatterns(content)) {
      hits.add('blocked_token_pattern');
    }

    final needsRedaction = hits.isNotEmpty ||
        label == SensitivityLabel.medium ||
        label == SensitivityLabel.mediumUnknown;

    if (!forPreview) {
      return RelaySensitivityAssessment(
        sensitivityLabel: label,
        redactionStatus:
            needsRedaction ? RedactionStatus.redacted : RedactionStatus.none,
        redactionRuleHits: hits,
        exportAllowed: label == SensitivityLabel.low && hits.isEmpty,
      );
    }

    if (label == SensitivityLabel.mediumUnknown && hits.isNotEmpty) {
      return RelaySensitivityAssessment(
        sensitivityLabel: label,
        redactionStatus: RedactionStatus.blocked,
        redactionRuleHits: hits,
        exportAllowed: false,
      );
    }

    return RelaySensitivityAssessment(
      sensitivityLabel: label,
      redactionStatus:
          needsRedaction ? RedactionStatus.redacted : RedactionStatus.none,
      redactionRuleHits: hits,
      exportAllowed: label == SensitivityLabel.low || needsRedaction,
    );
  }

  /// preview 텍스트에 regex redaction을 적용한다.
  String applyRedaction(String content, RelaySensitivityAssessment assessment) {
    if (assessment.redactionStatus == RedactionStatus.blocked) {
      return '[EXPORT BLOCKED: sensitivity ${assessment.sensitivityLabel.wireName}]';
    }
    var redacted = content;
    for (final pattern in _redactionPatterns) {
      redacted = redacted.replaceAll(pattern, '[REDACTED]');
    }
    redacted = redacted
        .replaceAll(
          RegExp(r'api[_-]?key\s*[:=]\s*\S+', caseSensitive: false),
          'api_key: [REDACTED]',
        )
        .replaceAll(
          RegExp(r'password\s*[:=]\s*\S+', caseSensitive: false),
          'password: [REDACTED]',
        );
    return redacted;
  }
}
