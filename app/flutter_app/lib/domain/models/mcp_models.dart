// MCP 관련 도메인 모델: tool 정의, 작업큐, 권한 토큰, 개인 아카이브 후보

enum TokenType { write, destructive, admin }

enum TicketStatus { pending, inProgress, completed, failed, cancelled }

class McpToolDefinition {
  final String name;
  final String description;
  final bool enabled;
  final TokenType? requiredToken;

  const McpToolDefinition({
    required this.name,
    required this.description,
    required this.enabled,
    this.requiredToken,
  });
}

class PermissionToken {
  final String id;
  final TokenType type;
  final String issuedTo; // AI agent 식별자
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String? documentId; // 특정 문서 제한 시

  const PermissionToken({
    required this.id,
    required this.type,
    required this.issuedTo,
    required this.issuedAt,
    required this.expiresAt,
    this.documentId,
  });
}

class WorkTicket {
  final String id;
  final String agentId;
  final String toolName;
  final Map<String, dynamic> params;
  final TicketStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;

  const WorkTicket({
    required this.id,
    required this.agentId,
    required this.toolName,
    required this.params,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
  });
}

// Phase 1: 모든 개인 데이터 추출 후보는 수동 승인 대상
class PersonalArchiveCandidate {
  final String id;
  final String sourceDocumentId;
  final String key;
  final String value;
  final double confidence;
  final DateTime extractedAt;
  final bool? approved; // null = 대기 중

  const PersonalArchiveCandidate({
    required this.id,
    required this.sourceDocumentId,
    required this.key,
    required this.value,
    required this.confidence,
    required this.extractedAt,
    this.approved,
  });
}
