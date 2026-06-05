// McpBridgeService: Flutter UI와 MCP TypeScript sidecar 연결 브리지

import '../models/mcp_models.dart';

abstract class McpBridgeService {
  /// sidecar 프로세스 시작
  Future<void> startSidecar();
  /// sidecar 프로세스 종료
  Future<void> stopSidecar();
  /// sidecar 상태 확인
  Future<bool> isSidecarRunning();

  /// MCP tool 목록 조회
  Future<List<McpToolDefinition>> listTools();
  /// 특정 tool 활성화/비활성화
  Future<void> setToolEnabled(String toolName, bool enabled);

  /// 작업큐 티켓 목록 조회
  Future<List<WorkTicket>> listTickets();
  /// 티켓 취소
  Future<void> cancelTicket(String ticketId);

  /// PermissionToken 발급 (사용자 승인 후)
  Future<PermissionToken> issueToken({
    required TokenType type,
    required String agentId,
    String? documentId,
    required Duration validity,
  });
  /// 토큰 폐기
  Future<void> revokeToken(String tokenId);
}
