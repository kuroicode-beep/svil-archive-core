// sac_desktop_shell.dart — tray 상주 / 창 닫기 / sidecar bootstrap (Sprint 13)

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/services/sidecar_process_manager.dart';
import '../domain/services/settings_service.dart';
import '../domain/services/windows_autostart_service.dart';

class SacDesktopShell with TrayListener, WindowListener {
  final SettingsService settingsService;
  final SidecarProcessManager sidecarProcessManager;
  final WindowsAutostartService windowsAutostartService;
  bool _initialized = false;
  bool _quitting = false;

  SacDesktopShell({
    required this.settingsService,
    required this.sidecarProcessManager,
    required this.windowsAutostartService,
  });

  /// Desktop shell(tray/window/sidecar bootstrap)을 초기화한다.
  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    await windowManager.ensureInitialized();
    windowManager.addListener(this);

    final settings = await settingsService.getSettings();
    await windowManager.setPreventClose(true);

    if (settings.closeToTray) {
      await _initTray();
    }

    await sidecarProcessManager.refresh();
    if (settings.autoStartSidecar) {
      await sidecarProcessManager.start();
    }

    _initialized = true;
  }

  /// tray icon과 menu를 초기화한다.
  Future<void> _initTray() async {
    trayManager.addListener(this);
    final iconPath = await _resolveTrayIconPath();
    if (iconPath != null) {
      await trayManager.setIcon(iconPath);
    }
    await trayManager.setToolTip('SAC — SVIL Archive Core');
    await _refreshTrayMenu();
  }

  /// tray menu를 현재 sidecar 상태로 갱신한다.
  Future<void> _refreshTrayMenu() async {
    final snapshot = sidecarProcessManager.currentSnapshot;
    final settings = await settingsService.getSettings();
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'SAC 열기'),
          MenuItem(key: 'hide', label: 'SAC 숨기기'),
          MenuItem(
            key: 'sidecar_status',
            label: 'MCP sidecar: ${snapshot.status.name}',
            disabled: true,
          ),
          MenuItem(key: 'sidecar_start', label: 'MCP sidecar 시작'),
          MenuItem(key: 'sidecar_stop', label: 'MCP sidecar 중지'),
          MenuItem(key: 'sidecar_restart', label: 'MCP sidecar 재시작'),
          MenuItem.separator(),
          MenuItem(
            key: 'autostart_toggle',
            label: 'Windows 시작 시 자동 실행',
            checked: settings.startWithWindows,
          ),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '완전히 종료'),
        ],
      ),
    );
  }

  /// tray icon 경로를 반환한다.
  Future<String?> _resolveTrayIconPath() async {
    try {
      final byteData = await rootBundle.load('assets/tray_icon.png');
      final file = File('${Directory.systemTemp.path}/sac_tray_icon.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// 앱을 완전히 종료한다.
  Future<void> quitCompletely() async {
    if (_quitting) return;
    _quitting = true;
    await sidecarProcessManager.dispose();
    if (Platform.isWindows) {
      final settings = await settingsService.getSettings();
      if (!settings.startWithWindows) {
        await windowsAutostartService.disable();
      }
    }
    await trayManager.destroy();
    await windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
      case 'hide':
        await windowManager.hide();
      case 'sidecar_start':
        await sidecarProcessManager.start(userInitiated: true);
        await _refreshTrayMenu();
      case 'sidecar_stop':
        await sidecarProcessManager.stop();
        await _refreshTrayMenu();
      case 'sidecar_restart':
        await sidecarProcessManager.restart();
        await _refreshTrayMenu();
      case 'autostart_toggle':
        await _toggleWindowsAutostart();
        await _refreshTrayMenu();
      case 'quit':
        await quitCompletely();
    }
  }

  /// Windows autostart 옵션을 토글한다.
  Future<void> _toggleWindowsAutostart() async {
    if (!Platform.isWindows) return;
    final settings = await settingsService.getSettings();
    if (settings.startWithWindows) {
      await windowsAutostartService.disable();
      await settingsService.saveSettings(
        settings.copyWith(startWithWindows: false, clearRegisteredAutostartExePath: true),
      );
    } else {
      final exe = Platform.resolvedExecutable;
      await windowsAutostartService.enable(exePath: exe);
      await settingsService.saveSettings(
        settings.copyWith(startWithWindows: true, registeredAutostartExePath: exe),
      );
    }
  }

  @override
  void onWindowClose() async {
    final settings = await settingsService.getSettings();
    if (settings.closeToTray) {
      await windowManager.hide();
      if (!_initialized) {
        await _initTray();
        _initialized = true;
      }
      return;
    }
    await quitCompletely();
  }
}
