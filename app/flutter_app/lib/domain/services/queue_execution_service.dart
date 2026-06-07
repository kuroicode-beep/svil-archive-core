// queue_execution_service.dart — ticket 실행 서비스 인터페이스

import '../models/ticket_execution.dart';

abstract class QueueExecutionService {
  /// 승인된 ticket의 dry-run preview를 생성한다.
  Future<DryRunPreview> createDryRunPreview(String ticketId);

  /// 승인된 ticket을 안전하게 실행한다.
  Future<TicketExecutionResult> executeApprovedTicket(String ticketId);

  /// ticket 실행 로그를 조회한다.
  Future<List<TicketExecutionLog>> listExecutionLogs(String ticketId);

  /// 실행 요약을 조회한다.
  Future<QueueExecutionSummary> getExecutionSummary();
}
