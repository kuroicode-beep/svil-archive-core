// ai_sync_prefix.dart — 다운로드 파일명 AI sync prefix 감지/제거 (Sprint 16)

/// 기본 AI sync prefix 목록 (작업지시문 02-1).
const List<String> kDefaultAiSyncPrefixes = [
  'ai_sync_chatgpt_',
  'ai_sync_claude_',
  'ai_sync_gemini_',
  'ai_sync_codex_',
  'ai_sync_cursor_',
  'ai_sync_manual_',
];

/// prefix 감지 결과.
class AiSyncPrefixMatch {
  final String originalFileName;
  final String strippedFileName;
  final String? matchedPrefix;
  final String sourceAi;

  const AiSyncPrefixMatch({
    required this.originalFileName,
    required this.strippedFileName,
    required this.matchedPrefix,
    required this.sourceAi,
  });

  bool get hasPrefix => matchedPrefix != null;
}

/// prefix 문자열에서 source AI 이름을 추출한다 (`ai_sync_chatgpt_` → `chatgpt`).
String sourceAiFromPrefix(String prefix) {
  var value = prefix;
  if (value.startsWith('ai_sync_')) {
    value = value.substring('ai_sync_'.length);
  }
  value = value.replaceAll(RegExp(r'_+$'), '');
  return value.isEmpty ? 'manual' : value;
}

/// 파일명이 등록된 prefix로 시작하면 prefix를 제거한다.
/// prefix는 파일명에만 적용하며, 제거 후 이름이 비면 원본을 유지한다.
AiSyncPrefixMatch stripAiSyncPrefix(
  String fileName, {
  List<String> prefixes = kDefaultAiSyncPrefixes,
}) {
  for (final prefix in prefixes) {
    if (prefix.isEmpty) continue;
    if (fileName.toLowerCase().startsWith(prefix.toLowerCase())) {
      final stripped = fileName.substring(prefix.length).trim();
      if (stripped.isEmpty) {
        // prefix만 있는 비정상 파일명 — 원본 유지, source AI만 기록.
        return AiSyncPrefixMatch(
          originalFileName: fileName,
          strippedFileName: fileName,
          matchedPrefix: prefix,
          sourceAi: sourceAiFromPrefix(prefix),
        );
      }
      return AiSyncPrefixMatch(
        originalFileName: fileName,
        strippedFileName: stripped,
        matchedPrefix: prefix,
        sourceAi: sourceAiFromPrefix(prefix),
      );
    }
  }
  return AiSyncPrefixMatch(
    originalFileName: fileName,
    strippedFileName: fileName,
    matchedPrefix: null,
    sourceAi: 'manual',
  );
}
