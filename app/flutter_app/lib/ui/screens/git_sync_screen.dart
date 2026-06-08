// git_sync_screen.dart — Git Sync + Download Watcher Import Queue UI (Sprint 16)

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/platform/path_adapter.dart';
import '../../data/services/download_watcher_service_impl.dart';
import '../../data/services/download_import_coordinator.dart';
import '../../domain/models/git_sync.dart';
import '../../domain/models/import_queue_item.dart';
import '../../domain/models/settings.dart';
import '../../domain/services/download_watcher_service.dart';
import '../../domain/services/git_sync_service.dart';
import '../../domain/services/import_queue_service.dart';
import '../../domain/services/settings_service.dart';

class GitSyncScreen extends StatefulWidget {
  final GitSyncService gitSyncService;
  final ImportQueueService importQueueService;
  final DownloadWatcherService downloadWatcherService;
  final DownloadImportCoordinator coordinator;
  final SettingsService settingsService;
  final String workspaceRoot;
  final VoidCallback? onImportCompleted;
  final Future<void> Function(DownloadWatcherSettings settings)? onDownloadsChanged;

  const GitSyncScreen({
    super.key,
    required this.gitSyncService,
    required this.importQueueService,
    required this.downloadWatcherService,
    required this.coordinator,
    required this.settingsService,
    required this.workspaceRoot,
    this.onImportCompleted,
    this.onDownloadsChanged,
  });

  @override
  State<GitSyncScreen> createState() => _GitSyncScreenState();
}

class _GitSyncScreenState extends State<GitSyncScreen> {
  GitStatus? _status;
  List<ImportQueueItem> _queue = [];
  AppSettings? _settings;
  bool _busy = false;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  /// Git 상태 + 큐 + 설정을 다시 로드한다.
  Future<void> _refreshAll() async {
    setState(() => _busy = true);
    try {
      final status = await widget.gitSyncService.status();
      final queue = await widget.importQueueService.listItems();
      final settings = await widget.settingsService.getSettings();
      if (!mounted) return;
      setState(() {
        _status = status;
        _queue = queue;
        _settings = settings;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 로그 영역에 메시지를 추가한다.
  void _appendLog(String message) {
    setState(() {
      _log = '${DateTime.now().toIso8601String().substring(11, 19)}  $message\n$_log';
    });
  }

  /// 다운로드 폴더를 1회 스캔한다.
  Future<void> _scanDownloads() async {
    setState(() => _busy = true);
    try {
      final added = await widget.downloadWatcherService.scanOnce();
      _appendLog('다운로드 스캔: 신규 ${added.length}건 감지');
      await _refreshAll();
    } catch (e) {
      _appendLog('다운로드 스캔 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 단일 큐 항목을 import 한다.
  Future<void> _importItem(ImportQueueItem item) async {
    setState(() => _busy = true);
    try {
      final outcome = await widget.coordinator.importItem(item.id);
      _appendLog('Import ${item.targetFileName}: ${outcome.status.name} (${outcome.message})');
      widget.onImportCompleted?.call();
      await _refreshAll();
    } catch (e) {
      _appendLog('Import 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 감지/대기 상태 큐 항목을 모두 import 하고 등록된 상대경로를 반환한다.
  Future<List<String>> _importAllPending() async {
    final pending = _queue
        .where((i) =>
            i.status == ImportQueueStatus.detected || i.status == ImportQueueStatus.pending)
        .toList();
    final committedPaths = <String>[];
    for (final item in pending) {
      final outcome = await widget.coordinator.importItem(item.id);
      _appendLog('Import ${item.targetFileName}: ${outcome.status.name}');
      final result = outcome.result;
      if (result != null) {
        for (final c in result.preview.candidates) {
          if (c.isImportable) committedPaths.add(c.relativePath);
        }
        final reportPath = result.reportPath;
        if (reportPath != null) {
          try {
            committedPaths.add(toRelativePath(widget.workspaceRoot, reportPath));
          } catch (_) {}
        }
      }
    }
    if (pending.isNotEmpty) widget.onImportCompleted?.call();
    return committedPaths;
  }

  /// 전체 감지 파일을 import 한다.
  Future<void> _importAll() async {
    setState(() => _busy = true);
    try {
      final paths = await _importAllPending();
      _appendLog('전체 Import 완료: ${paths.length} 파일');
      await _refreshAll();
    } catch (e) {
      _appendLog('전체 Import 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Git pull (fast-forward only).
  Future<void> _pull() async {
    setState(() => _busy = true);
    try {
      final status = await widget.gitSyncService.status();
      if (status.isDirty) {
        _appendLog('⚠️ working tree에 변경이 있습니다. pull 전 commit을 권장합니다.');
      }
      final git = _settings?.gitSync;
      final result = await widget.gitSyncService.pull(
        remoteName: git?.remoteName,
        branch: git?.branch,
      );
      _appendLog('git pull: ${result.success ? "성공" : "실패"} ${result.summary}');
      await _refreshAll();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// import된 파일만 commit 한다.
  Future<void> _commitPaths(List<String> paths, {bool thenPush = false}) async {
    if (paths.isEmpty) {
      _appendLog('commit 대상이 없습니다.');
      return;
    }
    final result = await widget.gitSyncService.commitPaths(paths, 'docs: import AI sync files');
    _appendLog('git commit (${paths.length}개): ${result.success ? "성공" : "실패"} ${result.summary}');
    if (thenPush && result.success) {
      final git = _settings?.gitSync;
      final push = await widget.gitSyncService.push(
        remoteName: git?.remoteName,
        branch: git?.branch,
      );
      _appendLog('git push: ${push.success ? "성공" : "실패"} ${push.summary}');
    }
  }

  /// Import + Commit (+ Push) 시퀀스.
  Future<void> _importCommit({bool push = false}) async {
    setState(() => _busy = true);
    try {
      final paths = await _importAllPending();
      await _commitPaths(paths, thenPush: push);
      await _refreshAll();
    } catch (e) {
      _appendLog('Import + Commit 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Pull + Import 시퀀스.
  Future<void> _pullImport() async {
    await _pull();
    await _scanDownloads();
    await _importAll();
  }

  /// .gitignore 필수 규칙을 보강한다.
  Future<void> _ensureGitignore() async {
    setState(() => _busy = true);
    try {
      final check = await widget.gitSyncService.ensureGitignore();
      if (check.missingRules.isEmpty) {
        _appendLog('.gitignore 필수 규칙 충족');
      } else {
        _appendLog('.gitignore 보강: ${check.missingRules.join(", ")}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Git Sync / 다운로드 감시',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            '웹 AI 결과물(ai_sync_* Markdown)을 다운로드 폴더에서 회수하고 Git으로 동기화합니다. '
            '원본은 삭제하지 않으며 자동 덮어쓰기/자동 push는 기본 OFF입니다.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          _gitStatusCard(status),
          const SizedBox(height: 16),
          _downloadFolderCard(),
          const SizedBox(height: 16),
          _actionsCard(),
          const SizedBox(height: 16),
          _queueCard(),
          const SizedBox(height: 16),
          _logCard(),
        ],
      ),
    );
  }

  Widget _gitStatusCard(GitStatus? status) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Git 상태', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (status == null)
              const Text('로딩 중...', style: TextStyle(fontSize: 16))
            else if (!status.isRepository)
              const Text('이 workspace는 Git 저장소가 아닙니다. (git init 필요)',
                  style: TextStyle(fontSize: 16, color: Colors.orange))
            else ...[
              Text('branch: ${status.branch}', style: const TextStyle(fontSize: 16)),
              Text('HEAD: ${status.headShort}', style: const TextStyle(fontSize: 16)),
              Text('상태: ${status.isDirty ? "변경 있음 (dirty)" : "깨끗함 (clean)"}',
                  style: TextStyle(
                      fontSize: 16,
                      color: status.isDirty ? Colors.orange : Colors.green)),
              Text('remote: ${status.hasRemote ? "있음" : "없음"}',
                  style: const TextStyle(fontSize: 16)),
              if (status.changedPaths.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('변경 파일 (${status.changedPaths.length}):',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ...status.changedPaths.take(10).map(
                      (path) => Text(path, style: const TextStyle(fontSize: 16)),
                    ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 감시 폴더 경로가 유효한지 검사한다.
  Future<String?> _validateWatchFolder(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      return '폴더가 존재하지 않습니다: $path';
    }
    try {
      await dir.list(followLinks: false).first;
    } catch (e) {
      return '폴더에 접근할 수 없습니다: $path';
    }
    return null;
  }

  /// 감시 폴더 설정을 저장하고 watcher를 재적용한다.
  Future<void> _saveDownloadSettings(DownloadWatcherSettings downloads) async {
    final current = _settings;
    if (current == null) return;
    await widget.settingsService.saveSettings(current.copyWith(downloads: downloads));
    await widget.onDownloadsChanged?.call(downloads);
    await _refreshAll();
  }

  /// 폴더 선택으로 감시 폴더를 변경한다.
  Future<void> _pickDownloadFolder() async {
    final current = _settings;
    if (current == null) return;
    final selected = await FilePicker.platform.getDirectoryPath();
    if (selected == null) return;
    final error = await _validateWatchFolder(selected);
    if (!mounted) return;
    if (error != null) {
      _appendLog(error);
      return;
    }
    await _saveDownloadSettings(current.downloads.copyWith(folderPath: selected));
    _appendLog('감시 폴더 저장: $selected');
  }

  /// 감시 폴더를 기본 Downloads로 복원한다.
  Future<void> _resetDownloadFolder() async {
    final current = _settings;
    if (current == null) return;
    await _saveDownloadSettings(current.downloads.copyWith(folderPath: ''));
    _appendLog('감시 폴더를 기본 Downloads로 복원');
  }

  Widget _downloadFolderCard() {
    final settings = _settings;
    final dl = settings?.downloads;
    final resolved = dl == null
        ? DownloadWatcherServiceImpl.resolveDefaultDownloadsFolder()
        : (dl.folderPath.isEmpty
            ? DownloadWatcherServiceImpl.resolveDefaultDownloadsFolder()
            : dl.folderPath);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('다운로드 감시 폴더',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('현재 감시 폴더: $resolved', style: const TextStyle(fontSize: 16)),
            Text(
              '실행 중: ${widget.downloadWatcherService.isRunning ? "ON" : "OFF"}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _btn('감시 폴더 변경', _busy ? null : _pickDownloadFolder),
                _btn('기본 폴더 복원', _busy ? null : _resetDownloadFolder),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('작업', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _btn('Git Status', _busy ? null : _refreshAll),
                _btn('Git Pull', _busy ? null : _pull),
                _btn('다운로드 스캔', _busy ? null : _scanDownloads),
                _btn('전체 Import', _busy ? null : _importAll),
                _btn('Import + Commit', _busy ? null : () => _importCommit()),
                _btn('Import + Commit + Push', _busy ? null : () => _importCommit(push: true)),
                _btn('Pull + Import', _busy ? null : _pullImport),
                _btn('.gitignore 보강', _busy ? null : _ensureGitignore),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _queueCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import Queue (${_queue.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_queue.isEmpty)
              const Text('감지된 파일이 없습니다. 다운로드 스캔을 실행하세요.',
                  style: TextStyle(fontSize: 16))
            else
              ..._queue.map(_queueTile),
          ],
        ),
      ),
    );
  }

  Widget _queueTile(ImportQueueItem item) {
    final canImport =
        item.status == ImportQueueStatus.detected || item.status == ImportQueueStatus.pending;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.targetFileName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  '원본: ${item.originalFileName}  ·  ${item.sourceAi}  ·  상태: ${item.status.name}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: (_busy || !canImport) ? null : () => _importItem(item),
              child: const Text('Import'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('로그', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_log.isEmpty ? '작업 로그가 여기에 표시됩니다.' : _log,
                style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, VoidCallback? onPressed) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
