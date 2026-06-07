// file_watcher_skeleton.dart — 파일 변경 감지 skeleton (Sprint 3)

typedef FileChangedCallback = Future<void> Function(String relativePath);

/// Sprint 3용 파일 watcher skeleton — OS별 완전 감시는 후속 Sprint에서 확장
class FileWatcherSkeleton {
  final FileChangedCallback onChanged;
  bool _watching = false;
  String? _workspaceRoot;

  FileWatcherSkeleton({required this.onChanged});

  /// watcher 시작을 표시한다.
  Future<void> start(String workspaceRoot) async {
    _workspaceRoot = workspaceRoot;
    _watching = true;
  }

  /// watcher를 중지한다.
  Future<void> stop() async {
    _watching = false;
    _workspaceRoot = null;
  }

  /// 외부에서 수동으로 파일 변경 이벤트를 전달한다.
  Future<void> notifyChanged(String relativePath) async {
    if (_watching) {
      await onChanged(relativePath);
    }
  }

  bool get isWatching => _watching;
  String? get workspaceRoot => _workspaceRoot;
}
