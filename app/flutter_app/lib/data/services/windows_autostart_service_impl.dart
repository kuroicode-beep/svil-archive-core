// windows_autostart_service_impl.dart — Windows startup folder autostart 구현

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/services/windows_autostart_service.dart';
import '../../domain/utils/path_masking.dart';

class WindowsAutostartServiceImpl implements WindowsAutostartService {
  static const String startupFileName = 'SAC_Autostart.cmd';

  final String? Function()? _appDataResolver;

  WindowsAutostartServiceImpl({String? Function()? appDataResolver})
      : _appDataResolver = appDataResolver;

  @override
  Future<WindowsAutostartStatus> getStatus({String? registeredExePath}) async {
    final currentExe = Platform.resolvedExecutable;
    final startupFile = _startupFilePath();
    if (startupFile == null) {
      final registered = registeredExePath?.trim();
      return WindowsAutostartStatus(
        enabled: false,
        pathMismatch: false,
        registeredExePathMasked:
            registered == null || registered.isEmpty ? null : maskArtifactPath(registered),
        currentExePathMasked: maskArtifactPath(currentExe),
      );
    }
    final enabled = File(startupFile).existsSync();
    final startupTarget = enabled ? _readStartupExePath(startupFile) : null;
    final registered = registeredExePath?.trim();
    final mismatch = enabled &&
        ((registered != null &&
                registered.isNotEmpty &&
                p.normalize(registered) != p.normalize(currentExe)) ||
            (startupTarget != null &&
                p.normalize(startupTarget) != p.normalize(currentExe)));
    final targetMissing = enabled &&
        startupTarget != null &&
        !File(startupTarget).existsSync();
    return WindowsAutostartStatus(
      enabled: enabled,
      pathMismatch: mismatch,
      targetMissing: targetMissing,
      registeredExePathMasked:
          registered == null || registered.isEmpty ? null : maskArtifactPath(registered),
      currentExePathMasked: maskArtifactPath(currentExe),
    );
  }

  @override
  Future<void> syncWithSettings({
    required bool startWithWindows,
    required String currentExePath,
  }) async {
    if (!Platform.isWindows) return;
    if (startWithWindows) {
      await enable(exePath: currentExePath);
      return;
    }
    await disable();
  }

  @override
  Future<void> enable({required String exePath}) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows autostart is only supported on Windows');
    }
    final startupFile = _startupFilePath();
    if (startupFile == null) {
      throw StateError('Windows startup folder not found');
    }
    final normalizedExe = p.normalize(exePath);
    final content = '@echo off\r\nstart "" "$normalizedExe"\r\n';
    await File(startupFile).writeAsString(content);
  }

  @override
  Future<void> disable() async {
    final startupFile = _startupFilePath();
    if (startupFile == null) return;
    final file = File(startupFile);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// startup cmd에 기록된 exe 경로를 읽는다.
  String? _readStartupExePath(String startupFile) {
    try {
      final content = File(startupFile).readAsStringSync();
      final match = RegExp(r'start\s+""\s+"([^"]+)"', caseSensitive: false).firstMatch(content);
      return match?.group(1)?.trim();
    } catch (_) {
      return null;
    }
  }

  /// Windows startup folder 경로를 반환한다.
  String? _startupFilePath() {
    if (!Platform.isWindows) return null;
    final appData = _appDataResolver?.call() ?? Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) return null;
    return p.join(
      appData,
      'Microsoft',
      'Windows',
      'Start Menu',
      'Programs',
      'Startup',
      startupFileName,
    );
  }
}
