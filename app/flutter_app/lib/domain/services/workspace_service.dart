// WorkspaceService: Workspace 생성/선택/관리 책임

import '../models/workspace.dart';

abstract class WorkspaceService {
  /// 저장된 Workspace 목록 반환
  Future<List<Workspace>> listWorkspaces();

  /// 새 Workspace 생성 (폴더 선택 후 .sac/ 초기화 포함)
  Future<Workspace> createWorkspace({
    required String name,
    required String rootPath,
  });

  /// Workspace 열기 (lastOpenedAt 갱신)
  Future<Workspace> openWorkspace(String workspaceId);

  /// 현재 활성 Workspace 반환
  Future<Workspace?> getActiveWorkspace();

  /// Workspace 삭제 (파일 삭제 아님, 앱 목록에서만 제거)
  Future<void> removeWorkspace(String workspaceId);
}
