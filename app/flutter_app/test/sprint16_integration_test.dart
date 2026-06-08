// sprint16_integration_test.dart — Git Sync + Download Watcher + Import Queue 통합 테스트

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/import/ai_sync_prefix.dart';
import 'package:sac_app/data/services/git_sync_service_impl.dart';
import 'package:sac_app/domain/models/import_queue_item.dart';
import 'package:sac_app/domain/services/search_service.dart';

void main() {
  late Directory tempDir;
  late Directory downloadsDir;
  late SacContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sac_sprint16_test_');
    downloadsDir = await Directory(p.join(tempDir.path, 'Downloads')).create(recursive: true);
    container = await SacContainer.create(registryDirectory: tempDir.path);
  });

  tearDown(() async {
    await container.disposeForTest();
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  Future<void> bindWorkspace() async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Sprint16 WS',
      rootPath: p.join(tempDir.path, 'SAC S16'),
    );
    await container.bindWorkspace(workspace);
  }

  /// 다운로드 폴더 감시 설정을 저장한다.
  Future<void> saveDownloadSettings({
    bool enabled = false,
    bool includeSubfolders = false,
    bool autoImport = false,
    String? folder,
  }) async {
    final current = await container.settingsService.getSettings();
    await container.settingsService.saveSettings(
      current.copyWith(
        downloads: current.downloads.copyWith(
          enabled: enabled,
          includeSubfolders: includeSubfolders,
          autoImport: autoImport,
          folderPath: folder ?? downloadsDir.path,
        ),
      ),
    );
  }

  /// 다운로드 폴더에 파일을 쓴다.
  Future<File> writeDownload(String name, {String content = '# AI Sync\n\nbody token s16'}) async {
    final file = File(p.join(downloadsDir.path, name));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  /// git 명령을 실행하고 실패 시 예외를 던진다.
  Future<void> git(List<String> args, String cwd) async {
    final result = await Process.run('git', args, workingDirectory: cwd);
    if (result.exitCode != 0) {
      throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
    }
  }

  /// 워크스페이스를 git working tree로 초기화한다 (main 브랜치 + identity).
  Future<void> initGitWorkspace() async {
    final root = container.activeWorkspace!.rootPath;
    await git(['init'], root);
    await git(['config', 'user.email', 'test@sac.local'], root);
    await git(['config', 'user.name', 'SAC Test'], root);
    await git(['config', 'commit.gpgsign', 'false'], root);
    // .sac 등 인덱스 산출물은 제외해 status가 깨끗하게 유지되도록 한다.
    final gitignore = File(p.join(root, '.gitignore'));
    await gitignore.writeAsString('.sac/\n*.zip\nbin/windows/\n');
    final readme = File(p.join(root, 'README.md'));
    await readme.writeAsString('# SAC DOCS test repo\n');
    await git(['add', 'README.md', '.gitignore'], root);
    await git(['commit', '-m', 'chore: seed'], root);
    // 기본 브랜치명을 main으로 통일한다.
    await git(['branch', '-M', 'main'], root);
  }

  // ---- 설정 저장/로드 (요구사항 1~4, 19~20) ----

  test('git repo url and sync interval persist', () async {
    await bindWorkspace();
    final current = await container.settingsService.getSettings();
    await container.settingsService.saveSettings(
      current.copyWith(
        gitSync: current.gitSync.copyWith(
          enabled: true,
          repoUrl: 'https://github.com/owner/repo.git',
          branch: 'main',
          syncIntervalMinutes: 45,
        ),
      ),
    );
    final loaded = await container.settingsService.getSettings();
    expect(loaded.gitSync.enabled, isTrue);
    expect(loaded.gitSync.repoUrl, 'https://github.com/owner/repo.git');
    expect(loaded.gitSync.branch, 'main');
    expect(loaded.gitSync.syncIntervalMinutes, 45);
    expect(loaded.gitSync.remoteName, 'origin');
  });

  test('download folder and prefixes persist', () async {
    await bindWorkspace();
    final current = await container.settingsService.getSettings();
    await container.settingsService.saveSettings(
      current.copyWith(
        downloads: current.downloads.copyWith(
          enabled: true,
          folderPath: downloadsDir.path,
          prefixes: ['ai_sync_chatgpt_', 'ai_sync_custom_'],
          scanIntervalMinutes: 7,
        ),
      ),
    );
    final loaded = await container.settingsService.getSettings();
    expect(loaded.downloads.enabled, isTrue);
    expect(loaded.downloads.folderPath, downloadsDir.path);
    expect(loaded.downloads.prefixes, contains('ai_sync_custom_'));
    expect(loaded.downloads.scanIntervalMinutes, 7);
  });

  test('safety defaults are OFF', () async {
    await bindWorkspace();
    final settings = await container.settingsService.getSettings();
    expect(settings.gitSync.autoCommit, isFalse);
    expect(settings.gitSync.autoPush, isFalse);
    expect(settings.downloads.enabled, isFalse);
    expect(settings.downloads.autoImport, isFalse);
  });

  // ---- prefix 제거 (요구사항 5) ----

  test('ai_sync_chatgpt_ prefix is stripped from filename', () {
    final match = stripAiSyncPrefix('ai_sync_chatgpt_20260608_sprint16_plan.md');
    expect(match.hasPrefix, isTrue);
    expect(match.strippedFileName, '20260608_sprint16_plan.md');
    expect(match.sourceAi, 'chatgpt');
  });

  test('non-prefixed filename is unchanged', () {
    final match = stripAiSyncPrefix('20260608_plain_note.md');
    expect(match.hasPrefix, isFalse);
    expect(match.strippedFileName, '20260608_plain_note.md');
  });

  // ---- 다운로드 감지 + 큐 (요구사항 7, 8, 9) ----

  test('scanOnce detects prefixed markdown and enqueues', () async {
    await bindWorkspace();
    await saveDownloadSettings(folder: downloadsDir.path);
    await writeDownload('ai_sync_chatgpt_20260608_detect.md');
    await writeDownload('not_ai_sync_ignore.md');

    final enqueued = await container.downloadWatcherService.scanOnce();
    expect(enqueued.length, 1);
    expect(enqueued.first.targetFileName, '20260608_detect.md');
    expect(enqueued.first.sourceAi, 'chatgpt');

    final queue = await container.importQueueService.listItems();
    expect(queue.length, 1);
    expect(queue.first.status, ImportQueueStatus.detected);
  });

  test('subfolder include OFF/ON controls detection', () async {
    await bindWorkspace();
    await Directory(p.join(downloadsDir.path, 'sub')).create(recursive: true);
    await writeDownload(p.join('sub', 'ai_sync_claude_20260608_nested.md'));

    await saveDownloadSettings(folder: downloadsDir.path, includeSubfolders: false);
    final off = await container.downloadWatcherService.scanOnce();
    expect(off.where((i) => i.targetFileName.contains('nested')).isEmpty, isTrue);

    await saveDownloadSettings(folder: downloadsDir.path, includeSubfolders: true);
    final on = await container.downloadWatcherService.scanOnce();
    expect(on.any((i) => i.targetFileName == '20260608_nested.md'), isTrue);
  });

  test('scanOnce does not re-enqueue already detected file', () async {
    await bindWorkspace();
    await saveDownloadSettings(folder: downloadsDir.path);
    await writeDownload('ai_sync_codex_20260608_once.md');
    final first = await container.downloadWatcherService.scanOnce();
    expect(first.length, 1);
    final second = await container.downloadWatcherService.scanOnce();
    expect(second.isEmpty, isTrue);
    final queue = await container.importQueueService.listItems();
    expect(queue.length, 1);
  });

  // ---- 수동 Import (요구사항 10, 11, 12, 13, 21, 22) ----

  test('manual import registers stripped file via approved snapshot', () async {
    await bindWorkspace();
    await saveDownloadSettings(folder: downloadsDir.path);
    final src = await writeDownload(
      'ai_sync_chatgpt_20260608_import.md',
      content: '# Import Me\n\nunique fts token zxq16search',
    );
    final enqueued = await container.downloadWatcherService.scanOnce();
    final item = enqueued.first;

    final outcome = await container.downloadImportCoordinator.importItem(item.id);
    expect(outcome.status, ImportQueueStatus.imported);
    expect(outcome.result, isNotNull);
    expect(outcome.result!.reportPath, isNotNull);

    final docs = await container.archiveService.listDocuments();
    expect(docs.length, 1);
    expect(docs.first.path, 'documents/Import/20260608_import.md');

    // 원본 다운로드 파일은 유지된다.
    expect(await src.exists(), isTrue);

    // FTS 검색 가능 (frontmatter 없이도 인덱싱).
    final search = await container.searchService.search(
      const SearchQuery(text: 'zxq16search', limit: 5),
    );
    expect(search, isNotEmpty);

    // 큐 상태 imported.
    final updated = await container.importQueueService.findById(item.id);
    expect(updated!.status, ImportQueueStatus.imported);
  });

  // ---- prefix 제거 후 중복 conflict (요구사항 6) ----

  test('stripped filename collision is reported as conflict', () async {
    await bindWorkspace();
    await saveDownloadSettings(folder: downloadsDir.path);

    final a = await writeDownload('ai_sync_chatgpt_20260608_dup.md', content: '# A\n\nbody-a');
    final firstEnqueue = await container.downloadWatcherService.scanOnce();
    final firstItem = firstEnqueue.firstWhere((i) => i.sourceAbsolutePath == p.normalize(a.path));
    final firstOutcome = await container.downloadImportCoordinator.importItem(firstItem.id);
    expect(firstOutcome.status, ImportQueueStatus.imported);

    // 다른 AI prefix지만 strip 후 동일 파일명 → 대상 경로 충돌.
    final b = await writeDownload('ai_sync_claude_20260608_dup.md', content: '# B\n\nbody-b');
    final secondEnqueue = await container.downloadWatcherService.scanOnce();
    final secondItem =
        secondEnqueue.firstWhere((i) => i.sourceAbsolutePath == p.normalize(b.path));
    final secondOutcome = await container.downloadImportCoordinator.importItem(secondItem.id);
    expect(secondOutcome.status, ImportQueueStatus.conflict);

    // 기존 파일은 덮어쓰이지 않는다.
    final existing = await container.archiveService.listDocuments();
    expect(existing.length, 1);
  });

  // ---- Git (요구사항 14, 15, 16, 17, 18) ----

  test('git status reports branch, head and clean state', () async {
    await bindWorkspace();
    await initGitWorkspace();
    final status = await container.gitSyncService.status();
    expect(status.isRepository, isTrue);
    expect(status.branch, 'main');
    expect(status.headShort, isNotEmpty);
    expect(status.isDirty, isFalse);
  });

  test('dirty working tree is detected for pull warning', () async {
    await bindWorkspace();
    await initGitWorkspace();
    final root = container.activeWorkspace!.rootPath;
    await File(p.join(root, 'README.md')).writeAsString('# changed\n');
    final status = await container.gitSyncService.status();
    expect(status.isDirty, isTrue);
    expect(status.changedPaths, isNotEmpty);
  });

  test('commitPaths stages only given paths, excludes sqlite', () async {
    await bindWorkspace();
    await initGitWorkspace();
    final root = container.activeWorkspace!.rootPath;
    // import 대상 md
    final docDir = Directory(p.join(root, 'documents', 'Import'));
    await docDir.create(recursive: true);
    await File(p.join(docDir.path, 'committed_s16.md')).writeAsString('# c\n\nbody');
    // .sac/sac.sqlite 는 이미 존재
    expect(await File(p.join(root, '.sac', 'sac.sqlite')).exists(), isTrue);

    final result = await container.gitSyncService
        .commitPaths(['documents/Import/committed_s16.md'], 'docs: import AI sync files');
    expect(result.success, isTrue);

    final tracked = await Process.run('git', ['ls-files'], workingDirectory: root);
    final files = tracked.stdout.toString();
    expect(files, contains('documents/Import/committed_s16.md'));
    expect(files.contains('.sac/sac.sqlite'), isFalse);
  });

  test('ensureGitignore adds required exclusions', () async {
    await bindWorkspace();
    await initGitWorkspace();
    final check = await container.gitSyncService.ensureGitignore();
    expect(check.exists, isTrue);
    final gitignore =
        await File(p.join(container.activeWorkspace!.rootPath, '.gitignore')).readAsString();
    expect(gitignore, contains('.sac/*.sqlite'));
    expect(gitignore, contains('*.zip'));
    expect(gitignore, contains('bin/windows/'));
  });

  test('push to local bare remote succeeds', () async {
    await bindWorkspace();
    await initGitWorkspace();
    final root = container.activeWorkspace!.rootPath;
    final remotePath = p.join(tempDir.path, 'remote.git');
    await Directory(remotePath).create(recursive: true);
    await git(['init', '--bare'], remotePath);
    await git(['remote', 'add', 'origin', remotePath], root);

    final push = await container.gitSyncService.push(remoteName: 'origin', branch: 'main');
    expect(push.success, isTrue);

    // 원격에 main 브랜치가 생성됐는지 확인.
    final remoteBranches = await Process.run('git', ['branch'], workingDirectory: remotePath);
    expect(remoteBranches.stdout.toString(), contains('main'));
  });

  test('pull --ff-only from remote applies upstream commit', () async {
    await bindWorkspace();
    await initGitWorkspace();
    final root = container.activeWorkspace!.rootPath;
    final remotePath = p.join(tempDir.path, 'remote.git');
    await Directory(remotePath).create(recursive: true);
    await git(['init', '--bare'], remotePath);
    await git(['remote', 'add', 'origin', remotePath], root);
    final seedPush =
        await container.gitSyncService.push(remoteName: 'origin', branch: 'main');
    expect(seedPush.success, isTrue);

    // 외부 clone에서 새 commit을 만들어 remote에 push.
    final clonePath = p.join(tempDir.path, 'clone');
    await git(['clone', '-b', 'main', remotePath, clonePath], tempDir.path);
    await git(['config', 'user.email', 'c@sac.local'], clonePath);
    await git(['config', 'user.name', 'Clone'], clonePath);
    await File(p.join(clonePath, 'upstream.md')).writeAsString('# upstream\n');
    await git(['add', 'upstream.md'], clonePath);
    await git(['commit', '-m', 'docs: upstream'], clonePath);
    await git(['push', 'origin', 'main'], clonePath);

    final pull = await container.gitSyncService.pull(remoteName: 'origin', branch: 'main');
    expect(pull.success, isTrue);
    expect(await File(p.join(root, 'upstream.md')).exists(), isTrue);
  });

  // ---- import report (요구사항 21) + 기본 OFF 회귀 ----

  test('import report file is created under .sac/imports', () async {
    await bindWorkspace();
    await saveDownloadSettings(folder: downloadsDir.path);
    await writeDownload('ai_sync_manual_20260608_report.md');
    final enqueued = await container.downloadWatcherService.scanOnce();
    final outcome = await container.downloadImportCoordinator.importItem(enqueued.first.id);
    expect(outcome.result!.reportPath, isNotNull);
    expect(await File(outcome.result!.reportPath!).exists(), isTrue);
    expect(outcome.result!.reportPath!.contains(p.join('.sac', 'imports')), isTrue);
  });

  test('git sync service default branch from constructor', () async {
    await bindWorkspace();
    final service = GitSyncServiceImpl(
      workspaceRoot: container.activeWorkspace!.rootPath,
      defaultBranch: 'main',
    );
    expect(await service.isGitRepository(), isFalse);
    final status = await service.status();
    expect(status.isRepository, isFalse);
  });
}
