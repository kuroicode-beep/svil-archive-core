// windows_autostart_service.dart — Windows startup autostart 등록 인터페이스

class WindowsAutostartStatus {
  final bool enabled;
  final bool pathMismatch;
  final bool targetMissing;
  final String? registeredExePathMasked;
  final String currentExePathMasked;

  const WindowsAutostartStatus({
    required this.enabled,
    required this.pathMismatch,
    this.targetMissing = false,
    this.registeredExePathMasked,
    required this.currentExePathMasked,
  });
}

abstract class WindowsAutostartService {
  /// 현재 autostart 등록 상태를 반환한다.
  Future<WindowsAutostartStatus> getStatus({String? registeredExePath});

  /// Windows startup에 SAC 실행 등록을 켠다.
  Future<void> enable({required String exePath});

  /// Windows startup 등록을 끈다.
  Future<void> disable();

  /// 설정과 startup cmd를 동기화한다 (빌드 교체 시 경로 갱신).
  Future<void> syncWithSettings({
    required bool startWithWindows,
    required String currentExePath,
  });
}
