// mcp_sidecar_path_resolver.dart — MCP sidecar dist 경로 탐지 (packaged / dev fallback)

import 'dart:io';

import 'package:path/path.dart' as p;

/// MCP sidecar dist 경로 탐지 출처.
enum McpSidecarPathSource {
  packaged,
  workspaceSetting,
  devFallback,
  notFound,
}

/// MCP sidecar dist 경로 탐지 결과.
class McpSidecarPathResolution {
  final String? distPath;
  final McpSidecarPathSource source;

  const McpSidecarPathResolution({
    required this.distPath,
    required this.source,
  });

  bool get isFound => distPath != null;
}

/// 실행 환경에서 MCP sidecar dist 경로를 탐지한다.
McpSidecarPathResolution resolveMcpSidecarPath({
  String? executablePath,
  String? workingDirectory,
  String? workspaceSidecarDistPath,
}) {
  final exePath = executablePath ?? Platform.resolvedExecutable;
  final cwd = workingDirectory ?? Directory.current.path;

  final packagedDist = p.normalize(p.join(p.dirname(exePath), 'mcp', 'sidecar', 'dist'));
  if (_distIndexExists(packagedDist)) {
    return McpSidecarPathResolution(
      distPath: packagedDist,
      source: McpSidecarPathSource.packaged,
    );
  }

  if (workspaceSidecarDistPath != null && workspaceSidecarDistPath.trim().isNotEmpty) {
    final workspaceDist = p.normalize(workspaceSidecarDistPath);
    if (_distIndexExists(workspaceDist)) {
      return McpSidecarPathResolution(
        distPath: workspaceDist,
        source: McpSidecarPathSource.workspaceSetting,
      );
    }
  }

  for (final candidate in _devFallbackCandidates(cwd)) {
    if (_distIndexExists(candidate)) {
      return McpSidecarPathResolution(
        distPath: candidate,
        source: McpSidecarPathSource.devFallback,
      );
    }
  }

  return const McpSidecarPathResolution(
    distPath: null,
    source: McpSidecarPathSource.notFound,
  );
}

/// dist 경로만 반환한다 (기존 호출부 호환).
String? resolveMcpSidecarDistPath({
  String? executablePath,
  String? workingDirectory,
  String? workspaceSidecarDistPath,
}) {
  return resolveMcpSidecarPath(
    executablePath: executablePath,
    workingDirectory: workingDirectory,
    workspaceSidecarDistPath: workspaceSidecarDistPath,
  ).distPath;
}

/// MCP bridge UI용 상태 라벨을 생성한다.
String mcpSidecarStatusLabel(McpSidecarPathResolution resolution) {
  if (resolution.distPath == null) {
    return 'sidecar 빌드 없음';
  }
  switch (resolution.source) {
    case McpSidecarPathSource.packaged:
      return '로컬 준비됨 (패키지 내 sidecar)';
    case McpSidecarPathSource.workspaceSetting:
      return '로컬 준비됨 (workspace 설정 경로)';
    case McpSidecarPathSource.devFallback:
      return '로컬 준비됨 (개발 경로 fallback)';
    case McpSidecarPathSource.notFound:
      return 'sidecar 빌드 없음';
  }
}

/// portable BUILD_MANIFEST.json 필수 필드와 민감정보 여부를 검증한다.
bool validatePortableBuildManifest(Map<String, dynamic> manifest) {
  if (manifest['mcp_sidecar_included'] != true) return false;
  if (manifest['mcp_sidecar_path'] != 'mcp/sidecar') return false;
  if (manifest['external_api_enabled'] != false) return false;
  if (manifest['remote_mcp_enabled'] != false) return false;

  final serialized = manifest.toString().toLowerCase();
  const blocked = ['api_key', 'apikey', 'secret', 'token', 'password'];
  for (final word in blocked) {
    if (serialized.contains(word)) return false;
  }

  for (final value in manifest.values) {
    if (value is String && p.isAbsolute(value)) {
      return false;
    }
  }
  return true;
}

/// dist/index.js 존재 여부를 확인한다.
bool _distIndexExists(String distPath) {
  return File(p.join(distPath, 'index.js')).existsSync();
}

/// 개발 환경 fallback dist 후보 경로를 반환한다.
List<String> _devFallbackCandidates(String workingDirectory) {
  return [
    p.normalize(p.join(workingDirectory, '..', '..', 'mcp', 'sidecar', 'dist')),
    p.normalize(p.join(workingDirectory, '..', 'mcp', 'sidecar', 'dist')),
    p.normalize(p.join(workingDirectory, 'mcp', 'sidecar', 'dist')),
  ];
}
