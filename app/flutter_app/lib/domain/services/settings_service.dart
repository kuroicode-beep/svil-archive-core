// SettingsService / ThemeService / TtsService: 앱 설정 서비스 인터페이스

import '../models/settings.dart';

abstract class SettingsService {
  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);
}

abstract class ThemeService {
  Future<ThemeSettings> getThemeSettings();
  Future<void> applyTheme(AppTheme theme);
  // 하단 푸터 고대비 토글 — 즉시 적용, 재시작 불필요
  Future<void> toggleHighContrast(bool enabled);
}

abstract class TtsService {
  /// 문서 전체 읽기 시작
  Future<void> speakDocument(String documentId);
  /// 특정 섹션 읽기
  Future<void> speakSection(String documentId, String headingPath);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> setSpeed(double multiplier);
  Future<TtsSettings> getTtsSettings();
  Future<void> saveTtsSettings(TtsSettings settings);
}
