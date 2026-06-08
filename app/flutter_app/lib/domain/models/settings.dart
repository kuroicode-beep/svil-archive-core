// AppSettings / ThemeSettings / TtsSettings: 앱 설정 도메인 모델

enum AppTheme { light, dark, highContrast, custom }

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
    );
  }
}
