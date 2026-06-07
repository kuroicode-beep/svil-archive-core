// mcp_bridge_status_service.dart — MCP bridge 상태 및 queue 연동 인터페이스

import '../models/work_queue.dart';

abstract class McpBridgeStatusService {
  /// 로컬 MCP bridge 상태를 확인한다.
  Future<McpBridgeStatus> checkStatus();

  /// MCP 도구 요청을 queue ticket으로 변환한다 (직접 실행 없음).
  Future<WorkQueueTicket> enqueueToolRequest(McpToolRequest request);
}
