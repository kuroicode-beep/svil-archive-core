// workspace_file_inventory_service.dart — workspace Markdown 인벤토리 인터페이스

abstract class WorkspaceFileInventoryService {
  /// workspace 내부 Markdown 파일 상대경로 목록을 반환한다.
  Future<List<String>> listWorkspaceMarkdownPaths();
}
