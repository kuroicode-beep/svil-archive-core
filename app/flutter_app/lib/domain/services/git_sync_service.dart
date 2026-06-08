// git_sync_service.dart — Git Sync 서비스 인터페이스 (Sprint 16)

import '../models/git_sync.dart';

abstract class GitSyncService {
  /// workspace가 Git working tree인지 확인한다.
  Future<bool> isGitRepository();

  /// 현재 Git 상태(branch/head/dirty/변경목록)를 반환한다.
  Future<GitStatus> status();

  /// remote에서 fast-forward로만 pull 한다 (자동 merge 충돌 해결 금지).
  Future<GitCommandResult> pull({String? remoteName, String? branch});

  /// 지정한 상대경로만 stage 후 commit 한다.
  Future<GitCommandResult> commitPaths(List<String> relativePaths, String message);

  /// remote로 push 한다 (force 금지).
  Future<GitCommandResult> push({String? remoteName, String? branch});

  /// .gitignore에 필수 제외 규칙이 있는지 검사하고, 누락 시 보강한다.
  Future<GitignoreCheck> ensureGitignore({bool autoFix = true});
}
