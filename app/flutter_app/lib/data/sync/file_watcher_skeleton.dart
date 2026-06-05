// file_watcher_skeleton.dart — 파일 변경 감지 skeleton (Sprint 2)

typedef FileChangedCallback = Future<void> Function(String relativePath);

/// Sprint 2용 파일 watcher skeleton — 실제 감시는 Sprint 3에서 완성한다.
class FileWatcherSkeleton {
  final FileChangedCallback onChanged;
  bool _watching = false;

  FileWatcherSkeleton({required this.onChanged});

  /// watcher 시작을 표시한다.
  Future<void> start(String workspaceRoot) async {
    _watching = true;
  }

  /// watcher를 중지한다.
  Future<void> stop() async {
    _watching = false;
  }

  /// 외부에서 수동으로 파일 변경 이벤트를 전달한다.
  Future<void> notifyChanged(String relativePath) async {
    if (_watching) {
      await onChanged(relativePath);
    }
  }

  bool get isWatching => _watching;
}
