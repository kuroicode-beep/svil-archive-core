// sidecar_process_manager_impl.dart — MCP sidecar process lifecycle SQLite-free 구현

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/sidecar_lifecycle.dart';
import '../../domain/services/settings_service.dart';
import '../../domain/services/sidecar_process_manager.dart';
import '../../domain/utils/mcp_sidecar_path_resolver.dart';
import '../../domain/utils/path_masking.dart' show maskArtifactPath;

typedef SidecarProcessStarter = Future<Process> Function({
  required String executable,
  required List<String> arguments,
  required String workingDirectory,
});

class SidecarProcessManagerImpl implements SidecarProcessManager {
  final SettingsService _settingsService;
  final SidecarProcessStarter _processStarter;
  final String? Function() _executablePathResolver;

  Process? _process;
  SidecarLifecycleSnapshot _snapshot = const SidecarLifecycleSnapshot(
    status: SidecarLifecycleStatus.disabled,
    pathResolution: McpSidecarPathResolution(
      distPath: null,
      source: McpSidecarPathSource.notFound,
    ),
  );

  SidecarProcessManagerImpl({
    required SettingsService settingsService,
    SidecarProcessStarter? processStarter,
    String? Function()? executablePathResolver,
  })  : _settingsService = settingsService,
        _processStarter = processStarter ?? _defaultProcessStarter,
        _executablePathResolver = executablePathResolver ?? (() => Platform.resolvedExecutable);

  @override
  SidecarLifecycleSnapshot get currentSnapshot => _snapshot;

  @override
  Future<SidecarLifecycleSnapshot> refresh() async {
    _snapshot = await _buildSnapshot();
    return _snapshot;
  }

  @override
  Future<SidecarLifecycleSnapshot> start({bool userInitiated = false}) async {
    final settings = await _settingsService.getSettings();
    if (!userInitiated && !settings.autoStartSidecar) {
      _snapshot = await _buildSnapshot();
      return _snapshot;
    }

    final path = resolveMcpSidecarPath(executablePath: _executablePathResolver());
    if (!path.isFound) {
      _snapshot = SidecarLifecycleSnapshot(
        status: SidecarLifecycleStatus.notFound,
        pathResolution: path,
        lastStartError: 'sidecar dist not found',
        autoStartEnabled: settings.autoStartSidecar,
      );
      return _snapshot;
    }

    if (await _isProcessAlive(_process)) {
      _snapshot = await _buildSnapshot(lastError: null);
      return _snapshot;
    }

    _snapshot = SidecarLifecycleSnapshot(
      status: SidecarLifecycleStatus.starting,
      pathResolution: path,
      maskedSidecarPath: maskArtifactPath(path.distPath!),
      autoStartEnabled: settings.autoStartSidecar,
    );

    try {
      final sidecarRoot = p.normalize(p.join(path.distPath!, '..'));
      _process = await _processStarter(
        executable: _nodeExecutable(),
        arguments: const ['dist/index.js'],
        workingDirectory: sidecarRoot,
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!await _isProcessAlive(_process)) {
        final code = await _process?.exitCode;
        throw StateError('sidecar exited early (code: $code)');
      }
      _snapshot = await _buildSnapshot(
        lastError: null,
        forceRunning: true,
        startedAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      _process = null;
      _snapshot = SidecarLifecycleSnapshot(
        status: SidecarLifecycleStatus.failed,
        pathResolution: path,
        maskedSidecarPath: maskArtifactPath(path.distPath!),
        lastStartError: e.toString(),
        autoStartEnabled: settings.autoStartSidecar,
      );
    }
    return _snapshot;
  }

  @override
  Future<SidecarLifecycleSnapshot> stop() async {
    final process = _process;
    _process = null;
    if (process != null) {
      try {
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(const Duration(seconds: 3), onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        });
      } catch (_) {
        process.kill(ProcessSignal.sigkill);
      }
    }
    _snapshot = await _buildSnapshot(forceStopped: true);
    return _snapshot;
  }

  @override
  Future<SidecarLifecycleSnapshot> restart() async {
    await stop();
    return start(userInitiated: true);
  }

  @override
  Future<void> dispose() async {
    final process = _process;
    _process = null;
    if (process != null) {
      try {
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(const Duration(seconds: 3), onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        });
      } catch (_) {
        process.kill(ProcessSignal.sigkill);
      }
    }
    _snapshot = SidecarLifecycleSnapshot(
      status: SidecarLifecycleStatus.stopped,
      pathResolution: _snapshot.pathResolution,
      maskedSidecarPath: _snapshot.maskedSidecarPath,
      autoStartEnabled: _snapshot.autoStartEnabled,
      lastStartedAt: null,
    );
  }

  /// 현재 설정과 프로세스 상태로 스냅샷을 구성한다.
  Future<SidecarLifecycleSnapshot> _buildSnapshot({
    String? lastError,
    bool forceRunning = false,
    bool forceStopped = false,
    DateTime? startedAt,
  }) async {
    final settings = await _settingsService.getSettings();
    final path = resolveMcpSidecarPath(executablePath: _executablePathResolver());
    final running = forceRunning || await _isProcessAlive(_process);
    final status = _resolveStatus(
      path: path,
      running: running,
      forceStopped: forceStopped,
      autoStartEnabled: settings.autoStartSidecar,
      lastError: lastError ?? _snapshot.lastStartError,
    );
    return SidecarLifecycleSnapshot(
      status: status,
      pathResolution: path,
      maskedSidecarPath: path.distPath == null ? null : maskArtifactPath(path.distPath!),
      lastStartError: lastError ?? (status == SidecarLifecycleStatus.failed ? _snapshot.lastStartError : null),
      autoStartEnabled: settings.autoStartSidecar,
      lastStartedAt: running ? (startedAt ?? _snapshot.lastStartedAt) : null,
    );
  }

  /// lifecycle 상태를 계산한다.
  SidecarLifecycleStatus _resolveStatus({
    required McpSidecarPathResolution path,
    required bool running,
    required bool forceStopped,
    required bool autoStartEnabled,
    String? lastError,
  }) {
    if (path.source == McpSidecarPathSource.notFound || path.distPath == null) {
      return SidecarLifecycleStatus.notFound;
    }
    if (running) {
      return path.source == McpSidecarPathSource.devFallback
          ? SidecarLifecycleStatus.fallbackRunning
          : SidecarLifecycleStatus.running;
    }
    if (lastError != null && lastError.isNotEmpty) {
      return SidecarLifecycleStatus.failed;
    }
    if (forceStopped) {
      return SidecarLifecycleStatus.stopped;
    }
    return SidecarLifecycleStatus.packagedReady;
  }

  /// node 실행 파일명을 반환한다.
  String _nodeExecutable() {
    return Platform.isWindows ? 'node.exe' : 'node';
  }

  /// 프로세스가 살아 있는지 확인한다.
  Future<bool> _isProcessAlive(Process? process) async {
    if (process == null) return false;
    try {
      await process.exitCode.timeout(const Duration(milliseconds: 50));
      return false;
    } on TimeoutException {
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 기본 sidecar process starter.
  static Future<Process> _defaultProcessStarter({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
  }) {
    return Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.normal,
    );
  }
}
