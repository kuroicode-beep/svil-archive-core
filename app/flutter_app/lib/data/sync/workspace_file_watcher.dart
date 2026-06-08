// workspace_file_watcher.dart — OS 파일 변경 감시 (debounce 포함)

import 'dart:async';
import 'dart:io';

import 'package:watcher/watcher.dart';

import '../platform/path_adapter.dart';

typedef FileChangedCallback = Future<void> Function(String relativePath);

/// Workspace documents 디렉터리를 재귀 감시한다.
class WorkspaceFileWatcher {
  final FileChangedCallback onChanged;
  final Duration debounceDuration;

  StreamSubscription<WatchEvent>? _subscription;
  DirectoryWatcher? _watcher;
  String? _workspaceRoot;
  final Map<String, Timer> _debounceTimers = {};

  WorkspaceFileWatcher({
    required this.onChanged,
    this.debounceDuration = const Duration(milliseconds: 300),
  });

  /// documents/ 하위 변경 감시를 시작한다.
  Future<void> start(String workspaceRoot) async {
    await stop();
    _workspaceRoot = workspaceRoot;
    final documentsDir = resolveWorkspacePath(workspaceRoot, 'documents');
    if (!await Directory(documentsDir).exists()) {
      await Directory(documentsDir).create(recursive: true);
    }
    _watcher = DirectoryWatcher(documentsDir);
    _subscription = _watcher!.events.listen(
      _handleWatchEvent,
      onError: (_) {},
    );
  }

  /// 감시를 중지한다.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _watcher = null;
    _workspaceRoot = null;
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }

  /// 테스트/수동 트리거용 변경 이벤트를 전달한다.
  Future<void> notifyChanged(String relativePath) async {
    if (_workspaceRoot != null) {
      await onChanged(relativePath);
    }
  }

  bool get isWatching => _watcher != null;

  /// WatchEvent를 debounce 후 상대경로 콜백으로 변환한다.
  void _handleWatchEvent(WatchEvent event) {
    final root = _workspaceRoot;
    if (root == null) return;
    if (event.type != ChangeType.MODIFY && event.type != ChangeType.ADD) {
      return;
    }
    if (!event.path.toLowerCase().endsWith('.md')) return;

    String relativePath;
    try {
      relativePath = toRelativePath(root, event.path);
    } catch (_) {
      return;
    }

    _debounceTimers[relativePath]?.cancel();
    _debounceTimers[relativePath] = Timer(debounceDuration, () {
      _debounceTimers.remove(relativePath);
      if (_workspaceRoot == null) return;
      onChanged(relativePath);
    });
  }
}
