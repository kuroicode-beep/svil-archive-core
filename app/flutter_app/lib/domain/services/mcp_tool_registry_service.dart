// mcp_tool_registry_service.dart — MCP tool registry 인터페이스

import '../models/work_queue.dart';

abstract class McpToolRegistryService {
  /// 등록된 MCP tool 목록을 조회한다.
  Future<List<McpToolSetting>> listTools();

  /// tool 활성화 여부를 설정한다.
  Future<void> setToolEnabled(String toolName, bool enabled);

  /// tool 활성화 여부를 확인한다.
  Future<bool> isToolEnabled(String toolName);

  /// 기본 tool registry를 초기화한다.
  Future<void> ensureDefaultTools();
}
