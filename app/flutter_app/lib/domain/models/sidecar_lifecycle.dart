// sidecar_lifecycle.dart — MCP sidecar process lifecycle 상태 모델

import '../utils/mcp_sidecar_path_resolver.dart';

/// Sidecar process lifecycle 상태.
enum SidecarLifecycleStatus {
  disabled,
  packagedReady,
  starting,
  running,
  stopped,
  failed,
  fallbackRunning,
  notFound,
}

/// Sidecar lifecycle 스냅샷.
class SidecarLifecycleSnapshot {
  final SidecarLifecycleStatus status;
  final McpSidecarPathResolution pathResolution;
  final String? maskedSidecarPath;
  final String? lastStartError;
  final bool autoStartEnabled;
  final DateTime? lastStartedAt;

  const SidecarLifecycleSnapshot({
    required this.status,
    required this.pathResolution,
    this.maskedSidecarPath,
    this.lastStartError,
    this.autoStartEnabled = false,
    this.lastStartedAt,
  });
}

/// lifecycle 상태를 UI 라벨로 변환한다.
String sidecarLifecycleStatusLabel(SidecarLifecycleStatus status) {
  switch (status) {
    case SidecarLifecycleStatus.disabled:
      return 'sidecar 비활성';
    case SidecarLifecycleStatus.packagedReady:
      return '패키지 내 sidecar 준비됨';
    case SidecarLifecycleStatus.starting:
      return 'sidecar 시작 중';
    case SidecarLifecycleStatus.running:
      return 'sidecar 실행 중';
    case SidecarLifecycleStatus.stopped:
      return 'sidecar 중지됨';
    case SidecarLifecycleStatus.failed:
      return 'sidecar 시작 실패';
    case SidecarLifecycleStatus.fallbackRunning:
      return 'fallback 경로 사용 중';
    case SidecarLifecycleStatus.notFound:
      return 'sidecar 없음';
  }
}
