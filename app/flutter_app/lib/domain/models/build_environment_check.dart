// build_environment_check.dart — 빌드/실행 환경 점검 모델

enum BuildCheckStatus { pass, warn, fail }

class BuildEnvironmentCheck {
  final String id;
  final String checkName;
  final BuildCheckStatus status;
  final String message;
  final DateTime checkedAt;

  const BuildEnvironmentCheck({
    required this.id,
    required this.checkName,
    required this.status,
    required this.message,
    required this.checkedAt,
  });
}
