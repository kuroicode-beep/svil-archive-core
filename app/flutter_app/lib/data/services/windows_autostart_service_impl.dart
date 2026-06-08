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
    final enabled = startupFile != null && File(startupFile).existsSync();
    final registered = registeredExePath?.trim();
    final mismatch = enabled &&
        registered != null &&
        registered.isNotEmpty &&
        p.normalize(registered) != p.normalize(currentExe);
    return WindowsAutostartStatus(
      enabled: enabled,
      pathMismatch: mismatch,
      registeredExePathMasked:
          registered == null || registered.isEmpty ? null : maskArtifactPath(registered),
      currentExePathMasked: maskArtifactPath(currentExe),
    );
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
