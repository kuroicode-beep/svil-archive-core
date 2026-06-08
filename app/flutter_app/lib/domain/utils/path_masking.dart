// path_masking.dart — RC artifact 경로 masking 유틸

/// 사용자 홈·민감 경로를 masking한다.
String maskArtifactPath(String path) {
  var masked = path;
  masked = masked.replaceAllMapped(
    RegExp(r'[A-Za-z]:\\Users\\[^\\]+', caseSensitive: false),
    (_) => r'C:\Users\***',
  );
  masked = masked.replaceAllMapped(
    RegExp(r'/Users/[^/]+'),
    (_) => '/Users/***',
  );
  masked = masked.replaceAllMapped(
    RegExp(r'\\Users\\[^\\]+', caseSensitive: false),
    (_) => r'\Users\***',
  );
  masked = masked.replaceAllMapped(
    RegExp(r'[A-Za-z]:\\home\\[^\\]+', caseSensitive: false),
    (_) => r'C:\home\***',
  );
  return masked;
}

/// export 본문에 secret/token/api key 패턴이 없는지 검사한다.
bool exportContainsSensitivePatterns(String text) {
  final lower = text.toLowerCase();
  const blocked = [
    'api_key',
    'api key',
    'secret_token',
    'secret token',
    'bearer ',
    'password=',
  ];
  for (final token in blocked) {
    if (lower.contains(token)) return true;
  }
  return false;
}
