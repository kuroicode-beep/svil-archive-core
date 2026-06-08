// sidecar_process_manager.dart — bundled MCP sidecar process lifecycle 인터페이스

import '../models/sidecar_lifecycle.dart';

abstract class SidecarProcessManager {
  SidecarLifecycleSnapshot get currentSnapshot;

  /// sidecar 경로와 프로세스 상태를 갱신한다.
  Future<SidecarLifecycleSnapshot> refresh();

  /// sidecar process를 시작한다.
  Future<SidecarLifecycleSnapshot> start({bool userInitiated = false});

  /// sidecar process를 중지한다.
  Future<SidecarLifecycleSnapshot> stop();

  /// sidecar process를 재시작한다.
  Future<SidecarLifecycleSnapshot> restart();

  /// 앱 종료 시 sidecar를 정리한다.
  Future<void> dispose();
}
