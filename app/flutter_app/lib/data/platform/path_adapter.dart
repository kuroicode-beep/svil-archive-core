// path_adapter.dart — 플랫폼 중립 경로 변환 유틸

import 'package:path/path.dart' as p;

/// Workspace 루트와 상대경로를 OS 절대경로로 변환한다.
String toAbsolutePath(String workspaceRoot, String relativePath) {
  final normalized = p.normalize(relativePath.replaceAll('\\', '/'));
  return p.normalize(p.join(workspaceRoot, normalized));
}

/// 절대경로를 Workspace 기준 상대경로로 변환한다.
String toRelativePath(String workspaceRoot, String absolutePath) {
  final rel = p.relative(absolutePath, from: workspaceRoot);
  return rel.replaceAll('\\', '/');
}

/// Markdown 문서 상대경로를 생성한다.
String buildDocumentRelativePath(String category, String fileName) {
  final safeCategory = category.isEmpty ? 'Dev' : category;
  final safeName = fileName.endsWith('.md') ? fileName : '$fileName.md';
  return p.posix.join('documents', safeCategory, safeName);
}

/// Workspace 내부 .sac 폴더 절대경로를 반환한다.
String sacDirectoryPath(String workspaceRoot) {
  return p.join(workspaceRoot, '.sac');
}

/// SQLite DB 파일 절대경로를 반환한다.
String databaseFilePath(String workspaceRoot) {
  return p.join(sacDirectoryPath(workspaceRoot), 'sac.sqlite');
}

/// sync_journal 폴더 절대경로를 반환한다.
String syncJournalDirectoryPath(String workspaceRoot) {
  return p.join(sacDirectoryPath(workspaceRoot), 'sync_journal');
}

/// settings.json 절대경로를 반환한다.
String settingsJsonPath(String workspaceRoot) {
  return p.join(sacDirectoryPath(workspaceRoot), 'settings.json');
}
