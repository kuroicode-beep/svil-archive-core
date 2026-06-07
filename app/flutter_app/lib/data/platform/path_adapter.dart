// path_adapter.dart — 플랫폼 중립 경로 변환 및 workspace 경계 검증

import 'package:path/path.dart' as p;

/// Workspace 경로 검증 실패 시 발생하는 예외
class WorkspacePathException implements Exception {
  final String message;
  const WorkspacePathException(this.message);

  @override
  String toString() => 'WorkspacePathException: $message';
}

/// 허용된 문서 카테고리 목록
const Set<String> kAllowedDocumentCategories = {
  'Dev',
  'Log',
  'Idea',
  'Research',
  'Blog',
  'Novel',
  'YT',
  'Resource',
  'IB',
};

/// 상대경로가 workspace 내부 전용인지 검증한다.
void assertSafeRelativePath(String relativePath) {
  if (relativePath.trim().isEmpty) {
    throw const WorkspacePathException('Relative path cannot be empty');
  }
  final normalized = p.posix.normalize(relativePath.replaceAll('\\', '/'));
  if (p.isAbsolute(normalized) ||
      normalized.startsWith('/') ||
      normalized.startsWith('\\\\')) {
    throw WorkspacePathException('Absolute paths are not allowed: $relativePath');
  }
  final segments = p.posix.split(normalized);
  if (segments.any((segment) => segment == '..')) {
    throw WorkspacePathException(
      'Parent directory traversal is not allowed: $relativePath',
    );
  }
}

/// 절대경로가 workspace root 내부인지 확인한다.
bool isPathInsideWorkspaceRoot(String workspaceRoot, String absolutePath) {
  final root = p.normalize(p.absolute(workspaceRoot));
  final target = p.normalize(p.absolute(absolutePath));
  final rel = p.relative(target, from: root);
  return !rel.startsWith('..') && !p.isAbsolute(rel);
}

/// workspace root 내부 절대경로로 안전하게 변환한다.
String resolveWorkspacePath(String workspaceRoot, String relativePath) {
  assertSafeRelativePath(relativePath);
  final root = p.normalize(p.absolute(workspaceRoot));
  final resolved = p.normalize(
    p.join(root, relativePath.replaceAll('\\', '/')),
  );
  if (!isPathInsideWorkspaceRoot(root, resolved)) {
    throw WorkspacePathException('Path escapes workspace root: $relativePath');
  }
  return resolved;
}

/// Workspace 루트와 상대경로를 OS 절대경로로 변환한다.
String toAbsolutePath(String workspaceRoot, String relativePath) {
  return resolveWorkspacePath(workspaceRoot, relativePath);
}

/// 절대경로를 Workspace 기준 상대경로로 변환한다.
String toRelativePath(String workspaceRoot, String absolutePath) {
  final root = p.normalize(p.absolute(workspaceRoot));
  final target = p.normalize(p.absolute(absolutePath));
  if (!isPathInsideWorkspaceRoot(root, target)) {
    throw WorkspacePathException('Path is outside workspace root: $absolutePath');
  }
  final rel = p.relative(target, from: root);
  return rel.replaceAll('\\', '/');
}

/// 문서 카테고리를 allowlist 기준으로 정규화한다.
String sanitizeDocumentCategory(String? category) {
  final value = (category ?? 'Dev').trim();
  if (!kAllowedDocumentCategories.contains(value)) {
    throw WorkspacePathException('Invalid document category: $value');
  }
  return value;
}

/// 파일명을 workspace 내부 문서 경로용으로 정규화한다.
String sanitizeDocumentFileName(String fileName) {
  final cleaned = fileName
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll('..', '_')
      .trim();
  if (cleaned.isEmpty) {
    throw const WorkspacePathException('Document file name cannot be empty');
  }
  return cleaned.endsWith('.md') ? cleaned : '$cleaned.md';
}

/// Markdown 문서 상대경로를 생성한다.
String buildDocumentRelativePath(String category, String fileName) {
  final safeCategory = sanitizeDocumentCategory(category);
  final safeName = sanitizeDocumentFileName(fileName);
  final relativePath = p.posix.join('documents', safeCategory, safeName);
  assertSafeRelativePath(relativePath);
  return relativePath;
}

/// createDocument 입력에서 안전한 상대경로를 결정한다.
String resolveCreateDocumentRelativePath({
  required String relativeDir,
  required String? type,
  required String title,
}) {
  final safeTitle = sanitizeDocumentFileName(title);
  final normalizedDir = relativeDir.replaceAll('\\', '/').trim();

  if (normalizedDir.isNotEmpty) {
    assertSafeRelativePath(normalizedDir);
    final parts = p.posix.split(p.posix.normalize(normalizedDir));
    if (parts.isNotEmpty && parts[0] == 'documents' && parts.length >= 2) {
      final category = sanitizeDocumentCategory(parts[1]);
      if (type != null && type.trim().isNotEmpty) {
        final typeCategory = sanitizeDocumentCategory(type);
        if (typeCategory != category) {
          throw WorkspacePathException(
            'type ($typeCategory) must match relativeDir category ($category)',
          );
        }
      }
      return buildDocumentRelativePath(category, safeTitle);
    }
    throw WorkspacePathException(
      'relativeDir must start with documents/<Category>: $relativeDir',
    );
  }

  return buildDocumentRelativePath(sanitizeDocumentCategory(type), safeTitle);
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

/// relativePath에서 문서 category를 추출한다.
String categoryFromRelativePath(String relativePath) {
  assertSafeRelativePath(relativePath);
  final parts = p.posix.split(p.posix.normalize(relativePath));
  if (parts.length >= 2 && parts[0] == 'documents') {
    return sanitizeDocumentCategory(parts[1]);
  }
  throw WorkspacePathException('Cannot resolve category from path: $relativePath');
}

/// 휴지통 내부 상대경로를 생성한다.
String buildTrashRelativePath(String documentId, String originalRelativePath) {
  final baseName = p.basename(originalRelativePath);
  final trashPath = p.posix.join('.sac', 'trash', '${documentId}_$baseName');
  assertSafeRelativePath(trashPath);
  return trashPath;
}
