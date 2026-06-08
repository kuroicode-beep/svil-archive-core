// path_masking.ts — workspace 경로 masking

/** 사용자 홈·민감 경로를 masking한다. */
export function maskArtifactPath(inputPath: string): string {
  let masked = inputPath;
  masked = masked.replace(/[A-Za-z]:\\Users\\[^\\]+/gi, 'C:\\Users\\***');
  masked = masked.replace(/\/Users\/[^/]+/g, '/Users/***');
  masked = masked.replace(/\\Users\\[^\\]+/gi, '\\Users\\***');
  masked = masked.replace(/[A-Za-z]:\\home\\[^\\]+/gi, 'C:\\home\\***');
  return masked;
}

/** 설정 값에 secret/token 패턴이 있으면 masking한다. */
export function maskSensitiveValue(key: string, value: string): string {
  const lower = key.toLowerCase();
  if (
    lower.includes('token') ||
    lower.includes('secret') ||
    lower.includes('api_key') ||
    lower.includes('password')
  ) {
    return '***';
  }
  if (/api[_-]?key/i.test(value) || /bearer\s+/i.test(value)) {
    return '***';
  }
  return value;
}

/** 응답 JSON에 절대경로가 포함되지 않았는지 검사한다. */
export function containsAbsolutePathLeak(text: string): boolean {
  return /[A-Za-z]:\\Users\\[^\\]+/i.test(text) || /\/Users\/[^/]+/i.test(text);
}
