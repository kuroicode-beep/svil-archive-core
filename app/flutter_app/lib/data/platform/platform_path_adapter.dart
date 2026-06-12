// platform_path_adapter.dart — Relay용 플랫폼 경로 정규화 및 다운로드 파일 판별

import 'dart:io';

import 'package:path/path.dart' as p;

/// 다운로드 완료 전으로 간주하는 임시 확장자.
const Set<String> kIgnoredDownloadExtensions = {
  '.crdownload',
  '.tmp',
  '.part',
  '.download',
  '.partial',
};

/// 경로 separator를 normalize하고 절대경로로 통일한다.
String normalizePlatformPath(String path) {
  return p.normalize(p.absolute(path));
}

/// Windows/macOS 기본 Downloads 폴더를 추정한다.
String resolveDefaultDownloadsFolder() {
  final env = Platform.environment;
  if (Platform.isMacOS) {
    final home = env['HOME'] ?? Directory.current.path;
    return normalizePlatformPath(p.join(home, 'Downloads'));
  }
  final home = env['USERPROFILE'] ?? env['HOME'] ?? Directory.current.path;
  return normalizePlatformPath(p.join(home, 'Downloads'));
}

/// 다운로드 중 임시 파일인지 판별한다.
bool isTemporaryDownloadFile(String filePath) {
  final ext = p.extension(filePath).toLowerCase();
  if (kIgnoredDownloadExtensions.contains(ext)) return true;
  final base = p.basename(filePath).toLowerCase();
  if (base.endsWith('.tmp') || base.contains('.crdownload')) return true;
  return false;
}

/// 감시 대상 md 후보인지 판별한다.
bool isMarkdownDownloadCandidate(String filePath) {
  if (isTemporaryDownloadFile(filePath)) return false;
  return p.extension(filePath).toLowerCase() == '.md';
}

/// `(1)` 복제 suffix를 제거한 idempotency용 경로를 만든다.
String normalizeSourcePathForIdempotency(String absolutePath) {
  final normalized = normalizePlatformPath(absolutePath);
  final dir = p.dirname(normalized);
  final base = p.basename(normalized);
  final stripped = base.replaceAll(RegExp(r'\(\d+\)(?=\.md$)', caseSensitive: false), '');
  return p.join(dir, stripped);
}

/// 파일 크기가 stableFor 동안 변하지 않을 때까지 대기한다.
Future<bool> waitForFileSizeStability(
  String filePath, {
  Duration stableFor = const Duration(seconds: 2),
  Duration pollInterval = const Duration(milliseconds: 200),
  Duration timeout = const Duration(seconds: 30),
}) async {
  final file = File(filePath);
  if (!await file.exists()) return false;

  final deadline = DateTime.now().add(timeout);
  int? lastSize;
  DateTime? stableSince;

  while (DateTime.now().isBefore(deadline)) {
    int size;
    try {
      size = await file.length();
    } catch (_) {
      return false;
    }

    if (lastSize == size) {
      stableSince ??= DateTime.now();
      if (DateTime.now().difference(stableSince) >= stableFor) {
        return true;
      }
    } else {
      lastSize = size;
      stableSince = null;
    }
    await Future<void>.delayed(pollInterval);
  }
  return false;
}
