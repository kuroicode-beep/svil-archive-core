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
  bool _windowInitialized = false;
  bool _settingsActivated = false;
  bool _trayInitialized = false;
  bool _quitting = false;

  SacDesktopShell({
    required this.settingsService,
    required this.sidecarProcessManager,
    required this.windowsAutostartService,
  });

  /// Workspace 바인딩 전 window close 방어만 초기화한다.
  Future<void> initializeEarly() async {
    if (_windowInitialized || kIsWeb) return;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    _windowInitialized = true;
  }

  /// Workspace DB 준비 후 tray/sidecar 설정을 반영한다.
  Future<void> activateFromSettings() async {
    if (_settingsActivated || kIsWeb) return;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    final settings = await settingsService.getSettings();
    if (Platform.isWindows) {
      final currentExe = Platform.resolvedExecutable;
      await windowsAutostartService.syncWithSettings(
        startWithWindows: settings.startWithWindows,
        currentExePath: currentExe,
      );
      if (settings.startWithWindows &&
          settings.registeredAutostartExePath != currentExe) {
        await settingsService.saveSettings(
          settings.copyWith(registeredAutostartExePath: currentExe),
        );
      }
    }
    await sidecarProcessManager.refresh();
    if (settings.autoStartSidecar) {
      await sidecarProcessManager.start();
    }

    if (settings.closeToTray) {
      await _tryInitTray();
    }

    _settingsActivated = true;
  }

  /// desktop plugin이 없는 테스트 환경에서는 tray 초기화를 건너뛴다.
  Future<void> _tryInitTray() async {
    if (!_windowInitialized) return;
    try {
      await _initTray();
    } catch (_) {
      // headless flutter test — tray_manager/window_manager 미등록
    }
  }

  /// tray icon과 menu를 초기화한다.
  Future<void> _initTray() async {
    if (_trayInitialized) {
      await _refreshTrayMenu();
      return;
    }
    trayManager.addListener(this);
    final iconPath = await _resolveTrayIconPath();
    if (iconPath != null) {
      await trayManager.setIcon(iconPath);
    }
    await trayManager.setToolTip('SAC — SVIL Archive Core');
    await _refreshTrayMenu();
    _trayInitialized = true;
  }

  /// DB 미준비 시에도 안전한 closeToTray 기본값을 반환한다.
  Future<bool> _shouldCloseToTray() async {
    try {
      final settings = await settingsService.getSettings();
      return settings.closeToTray;
    } catch (_) {
      return true;
    }
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
    if (await _shouldCloseToTray()) {
      await windowManager.hide();
      if (!_trayInitialized) {
        await _tryInitTray();
      }
      return;
    }
    await quitCompletely();
  }
}
