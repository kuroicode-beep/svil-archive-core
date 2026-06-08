// AppSettings / ThemeSettings / TtsSettings: 앱 설정 도메인 모델

import '../../data/import/ai_sync_prefix.dart';

enum AppTheme { light, dark, highContrast, custom }

/// Git Sync 설정 (Sprint 16). 안전 기본값은 모두 수동/OFF.
class GitSyncSettings {
  final bool enabled;
  final String repoUrl;
  final String branch;
  final String remoteName;
  final bool autoCommit;
  final bool autoPush;
  final int syncIntervalMinutes;

  const GitSyncSettings({
    this.enabled = false,
    this.repoUrl = '',
    this.branch = 'main',
    this.remoteName = 'origin',
    this.autoCommit = false,
    this.autoPush = false,
    this.syncIntervalMinutes = 30,
  });

  GitSyncSettings copyWith({
    bool? enabled,
    String? repoUrl,
    String? branch,
    String? remoteName,
    bool? autoCommit,
    bool? autoPush,
    int? syncIntervalMinutes,
  }) {
    return GitSyncSettings(
      enabled: enabled ?? this.enabled,
      repoUrl: repoUrl ?? this.repoUrl,
      branch: branch ?? this.branch,
      remoteName: remoteName ?? this.remoteName,
      autoCommit: autoCommit ?? this.autoCommit,
      autoPush: autoPush ?? this.autoPush,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
    );
  }
}

/// 다운로드 폴더 감시 설정 (Sprint 16). 안전 기본값은 모두 OFF.
class DownloadWatcherSettings {
  final bool enabled;
  final String folderPath;
  final List<String> prefixes;
  final bool includeSubfolders;
  final bool autoImport;
  final int scanIntervalMinutes;

  const DownloadWatcherSettings({
    this.enabled = false,
    this.folderPath = '',
    this.prefixes = kDefaultAiSyncPrefixes,
    this.includeSubfolders = false,
    this.autoImport = false,
    this.scanIntervalMinutes = 5,
  });

  DownloadWatcherSettings copyWith({
    bool? enabled,
    String? folderPath,
    List<String>? prefixes,
    bool? includeSubfolders,
    bool? autoImport,
    int? scanIntervalMinutes,
  }) {
    return DownloadWatcherSettings(
      enabled: enabled ?? this.enabled,
      folderPath: folderPath ?? this.folderPath,
      prefixes: prefixes ?? this.prefixes,
      includeSubfolders: includeSubfolders ?? this.includeSubfolders,
      autoImport: autoImport ?? this.autoImport,
      scanIntervalMinutes: scanIntervalMinutes ?? this.scanIntervalMinutes,
    );
  }
}

enum TtsEngine { system, ollama, external }

class ThemeSettings {
  final AppTheme theme;
  final bool highContrastEnabled;
  final double fontSizeBase; // 기본값 16.0

  const ThemeSettings({
    this.theme = AppTheme.light,
    this.highContrastEnabled = false,
    this.fontSizeBase = 16.0,
  });

  ThemeSettings copyWith({
    AppTheme? theme,
    bool? highContrastEnabled,
    double? fontSizeBase,
  }) {
    return ThemeSettings(
      theme: theme ?? this.theme,
      highContrastEnabled: highContrastEnabled ?? this.highContrastEnabled,
      fontSizeBase: fontSizeBase ?? this.fontSizeBase,
    );
  }
}

class TtsSettings {
  final TtsEngine engine;
  final double speedMultiplier; // 0.5 ~ 2.0
  final bool highlightCurrentSentence;

  const TtsSettings({
    this.engine = TtsEngine.system,
    this.speedMultiplier = 1.0,
    this.highlightCurrentSentence = true,
  });
}

class AppSettings {
  final String workspaceId;
  final ThemeSettings theme;
  final TtsSettings tts;
  final bool mcpEnabled;
  final String ollamaEndpoint;
  final bool externalApiEnabled;
  final bool autoStartSidecar;
  final bool closeToTray;
  final bool startWithWindows;
  final String? registeredAutostartExePath;
  final GitSyncSettings gitSync;
  final DownloadWatcherSettings downloads;

  const AppSettings({
    required this.workspaceId,
    required this.theme,
    required this.tts,
    this.mcpEnabled = false,
    this.ollamaEndpoint = 'http://127.0.0.1:11434',
    this.externalApiEnabled = false,
    this.autoStartSidecar = false,
    this.closeToTray = true,
    this.startWithWindows = false,
    this.registeredAutostartExePath,
    this.gitSync = const GitSyncSettings(),
    this.downloads = const DownloadWatcherSettings(),
  });

  AppSettings copyWith({
    String? workspaceId,
    ThemeSettings? theme,
    TtsSettings? tts,
    bool? mcpEnabled,
    String? ollamaEndpoint,
    bool? externalApiEnabled,
    bool? autoStartSidecar,
    bool? closeToTray,
    bool? startWithWindows,
    String? registeredAutostartExePath,
    bool clearRegisteredAutostartExePath = false,
    GitSyncSettings? gitSync,
    DownloadWatcherSettings? downloads,
  }) {
    return AppSettings(
      workspaceId: workspaceId ?? this.workspaceId,
      theme: theme ?? this.theme,
      tts: tts ?? this.tts,
      mcpEnabled: mcpEnabled ?? this.mcpEnabled,
      ollamaEndpoint: ollamaEndpoint ?? this.ollamaEndpoint,
      externalApiEnabled: externalApiEnabled ?? this.externalApiEnabled,
      autoStartSidecar: autoStartSidecar ?? this.autoStartSidecar,
      closeToTray: closeToTray ?? this.closeToTray,
      startWithWindows: startWithWindows ?? this.startWithWindows,
      registeredAutostartExePath: clearRegisteredAutostartExePath
          ? null
          : (registeredAutostartExePath ?? this.registeredAutostartExePath),
      gitSync: gitSync ?? this.gitSync,
      downloads: downloads ?? this.downloads,
    );
  }
}
