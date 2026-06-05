// DesignAssetRegistry: 디자인 소스 폴더(asset/design/) 등록/조회 인터페이스
// 앱 런타임 asset과 디자인 소스를 명확히 구분하기 위한 경계

class DesignAssetEntry {
  final String relativePath;  // asset/design/ 기준 상대경로
  final String tool;          // stitch | claude_design | figma | references | exports
  final String? description;
  final DateTime addedAt;

  const DesignAssetEntry({
    required this.relativePath,
    required this.tool,
    this.description,
    required this.addedAt,
  });
}

abstract class DesignAssetRegistry {
  /// 디자인 소스 항목 등록
  Future<void> register(DesignAssetEntry entry);

  /// 도구별 항목 목록 조회
  Future<List<DesignAssetEntry>> listByTool(String tool);

  /// 전체 항목 목록 조회
  Future<List<DesignAssetEntry>> listAll();

  /// 항목 삭제 (파일 삭제 아님, 레지스트리에서만)
  Future<void> unregister(String relativePath);
}
