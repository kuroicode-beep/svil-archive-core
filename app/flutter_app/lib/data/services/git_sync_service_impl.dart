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
    final paths = relativePaths.where((e) => e.trim().isNotEmpty).toList();
    if (paths.isEmpty) {
      return const GitCommandResult(
        success: false,
        command: 'git commit',
        stdout: '',
        stderr: 'commit 대상 경로가 없습니다.',
        exitCode: -1,
      );
    }
    // commit 대상 제한 — 지정한 경로만 stage 한다.
    final addResult = await _run(['add', '--', ...paths]);
    if (!addResult.success) {
      return addResult;
    }
    return _run(['commit', '-m', message, '--', ...paths]);
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
