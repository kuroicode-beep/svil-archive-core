// git_sync_service_impl.dart — git CLI 기반 Git Sync 구현 (Sprint 16)

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/git_sync.dart';
import '../../domain/services/git_sync_service.dart';

/// SAC DOCS workspace에 필요한 .gitignore 필수 규칙 (작업지시문 07).
const List<String> kRequiredGitignoreRules = [
  '.sac/*.sqlite',
  '.sac/*.sqlite-wal',
  '.sac/*.sqlite-shm',
  '.sac/cache/',
  '.sac/tmp/',
  '.sac/logs/',
  '.env',
  '.env.*',
  'secrets.*',
  'bin/windows/',
  '*.zip',
];

/// commit 대상에서 항상 제외해야 하는 경로인지 판별한다 (작업지시문 06·10).
/// 서비스 레벨 최종 방어선 — UI가 잘못된 경로를 넘겨도 차단한다.
bool isExcludedFromCommit(String relativePath) {
  final path = relativePath.replaceAll('\\', '/').trim();
  if (path.isEmpty) return true;
  final lower = path.toLowerCase();
  final base = lower.split('/').last;

  // SQLite 인덱스 산출물 (.sac 하위 어디든)
  if (lower.endsWith('.sqlite') ||
      lower.endsWith('.sqlite-wal') ||
      lower.endsWith('.sqlite-shm')) {
    return true;
  }
  // .sac 캐시/임시/로그/백업
  if (lower.startsWith('.sac/cache/') ||
      lower.startsWith('.sac/tmp/') ||
      lower.startsWith('.sac/logs/') ||
      lower.startsWith('.sac/backups/')) {
    return true;
  }
  // 패키지/빌드 산출물
  if (lower.startsWith('bin/windows/') || lower.endsWith('.zip')) {
    return true;
  }
  // 비밀/환경 파일
  if (base == '.env' || base.startsWith('.env.') || base.startsWith('secrets.')) {
    return true;
  }
  return false;
}

class GitSyncServiceImpl implements GitSyncService {
  final String _workspaceRoot;
  final String _defaultRemoteName;
  final String _defaultBranch;

  GitSyncServiceImpl({
    required String workspaceRoot,
    String defaultRemoteName = 'origin',
    String defaultBranch = 'main',
  })  : _workspaceRoot = workspaceRoot,
        _defaultRemoteName = defaultRemoteName,
        _defaultBranch = defaultBranch;

  /// git 명령을 workspace root에서 실행한다.
  Future<GitCommandResult> _run(List<String> args) async {
    try {
      final result = await Process.run(
        'git',
        args,
        workingDirectory: _workspaceRoot,
        runInShell: false,
      );
      return GitCommandResult(
        success: result.exitCode == 0,
        command: 'git ${args.join(' ')}',
        stdout: (result.stdout ?? '').toString(),
        stderr: (result.stderr ?? '').toString(),
        exitCode: result.exitCode,
      );
    } catch (e) {
      return GitCommandResult(
        success: false,
        command: 'git ${args.join(' ')}',
        stdout: '',
        stderr: 'git 실행 실패: $e',
        exitCode: -1,
      );
    }
  }

  @override
  Future<bool> isGitRepository() async {
    final result = await _run(['rev-parse', '--is-inside-work-tree']);
    return result.success && result.stdout.trim() == 'true';
  }

  @override
  Future<GitStatus> status() async {
    if (!await isGitRepository()) {
      return GitStatus.notRepository('Not a git repository: $_workspaceRoot');
    }
    final branchResult = await _run(['rev-parse', '--abbrev-ref', 'HEAD']);
    final headResult = await _run(['rev-parse', '--short', 'HEAD']);
    final porcelain = await _run(['status', '--porcelain']);
    final remotes = await _run(['remote']);

    final changedPaths = porcelain.stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.length > 3 ? line.substring(3) : line)
        .toList();

    return GitStatus(
      isRepository: true,
      branch: branchResult.stdout.trim(),
      headShort: headResult.success ? headResult.stdout.trim() : '',
      isDirty: changedPaths.isNotEmpty,
      changedPaths: changedPaths,
      hasRemote: remotes.stdout.trim().isNotEmpty,
    );
  }

  @override
  Future<GitCommandResult> pull({String? remoteName, String? branch}) async {
    final remote = (remoteName == null || remoteName.isEmpty) ? _defaultRemoteName : remoteName;
    final br = (branch == null || branch.isEmpty) ? _defaultBranch : branch;
    // fast-forward만 허용 — 자동 merge / 충돌 해결 금지.
    return _run(['pull', '--ff-only', remote, br]);
  }

  @override
  Future<GitCommandResult> commitPaths(List<String> relativePaths, String message) async {
    final requested = relativePaths.where((e) => e.trim().isNotEmpty).toList();
    // 서비스 레벨 최종 방어선 — 금지 경로(.sqlite/zip/bin/secrets/.env/cache·logs)를 제거한다.
    final excluded = requested.where(isExcludedFromCommit).toList();
    final paths = requested.where((p) => !isExcludedFromCommit(p)).toList();
    if (paths.isEmpty) {
      return GitCommandResult(
        success: false,
        command: 'git commit',
        stdout: '',
        stderr: excluded.isNotEmpty
            ? 'commit 대상이 모두 제외 규칙에 해당합니다: ${excluded.join(', ')}'
            : 'commit 대상 경로가 없습니다.',
        exitCode: -1,
      );
    }
    // commit 대상 제한 — 허용된 경로만 stage 한다.
    final addResult = await _run(['add', '--', ...paths]);
    if (!addResult.success) {
      return addResult;
    }
    final commitResult = await _run(['commit', '-m', message, '--', ...paths]);
    if (excluded.isEmpty) return commitResult;
    // 제외된 경로를 결과에 알린다.
    return GitCommandResult(
      success: commitResult.success,
      command: commitResult.command,
      stdout: commitResult.stdout,
      stderr: '${commitResult.stderr}\n제외된 경로(${excluded.length}): ${excluded.join(', ')}'.trim(),
      exitCode: commitResult.exitCode,
    );
  }

  @override
  Future<GitCommandResult> push({String? remoteName, String? branch}) async {
    final remote = (remoteName == null || remoteName.isEmpty) ? _defaultRemoteName : remoteName;
    final br = (branch == null || branch.isEmpty) ? _defaultBranch : branch;
    // force push 금지 — 일반 push만 수행한다.
    return _run(['push', remote, br]);
  }

  @override
  Future<GitignoreCheck> ensureGitignore({bool autoFix = true}) async {
    final gitignorePath = p.join(_workspaceRoot, '.gitignore');
    final file = File(gitignorePath);
    final exists = await file.exists();
    final existingLines = exists
        ? (await file.readAsLines()).map((l) => l.trim()).toSet()
        : <String>{};

    final missing = kRequiredGitignoreRules
        .where((rule) => !existingLines.contains(rule))
        .toList();

    if (missing.isEmpty || !autoFix) {
      return GitignoreCheck(exists: exists, missingRules: missing, updated: false);
    }

    final buffer = StringBuffer();
    if (exists) {
      final current = await file.readAsString();
      buffer.write(current);
      if (current.isNotEmpty && !current.endsWith('\n')) {
        buffer.write('\n');
      }
    }
    buffer.write('\n# SAC Sprint 16 — required exclusions\n');
    for (final rule in missing) {
      buffer.write('$rule\n');
    }
    await file.writeAsString(buffer.toString());

    return GitignoreCheck(exists: true, missingRules: missing, updated: true);
  }
}
