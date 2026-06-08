// git_sync.dart — Git Sync 상태/결과 모델 (Sprint 16)

/// Git working tree 상태.
class GitStatus {
  final bool isRepository;
  final String branch;
  final String headShort;
  final bool isDirty;
  final List<String> changedPaths;
  final bool hasRemote;
  final String? errorMessage;

  const GitStatus({
    required this.isRepository,
    this.branch = '',
    this.headShort = '',
    this.isDirty = false,
    this.changedPaths = const [],
    this.hasRemote = false,
    this.errorMessage,
  });

  /// Git repo가 아닌 경우의 기본 상태.
  factory GitStatus.notRepository([String? message]) {
    return GitStatus(isRepository: false, errorMessage: message);
  }
}

/// Git 명령 실행 결과.
class GitCommandResult {
  final bool success;
  final String command;
  final String stdout;
  final String stderr;
  final int exitCode;

  const GitCommandResult({
    required this.success,
    required this.command,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  /// 사람이 읽을 수 있는 출력 요약.
  String get summary {
    final out = stdout.trim();
    final err = stderr.trim();
    if (out.isNotEmpty && err.isNotEmpty) return '$out\n$err';
    return out.isNotEmpty ? out : err;
  }
}

/// .gitignore 검사 결과.
class GitignoreCheck {
  final bool exists;
  final List<String> missingRules;
  final bool updated;

  const GitignoreCheck({
    required this.exists,
    required this.missingRules,
    required this.updated,
  });

  bool get isComplete => missingRules.isEmpty;
}
