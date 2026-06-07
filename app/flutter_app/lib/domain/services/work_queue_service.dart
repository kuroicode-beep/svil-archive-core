// work_queue_service.dart — 작업큐 티켓 서비스 인터페이스

import '../models/work_queue.dart';

abstract class WorkQueueService {
  /// AI 또는 도구 요청을 작업 티켓으로 등록한다.
  Future<WorkQueueTicket> createTicket(CreateWorkQueueTicketInput input);

  /// 대기 중인 작업 티켓을 조회한다.
  Future<List<WorkQueueTicket>> listPendingTickets();

  /// 전체 작업 티켓을 조회한다.
  Future<List<WorkQueueTicket>> listAllTickets();

  /// 작업큐 요약을 조회한다.
  Future<WorkQueueSummary> getSummary();

  /// 작업 티켓을 승인한다.
  Future<void> approveTicket(
    String ticketId, {
    String approverActor = 'user',
    String? permissionTokenId,
  });

  /// 작업 티켓을 거절한다.
  Future<void> rejectTicket(String ticketId, String reason);

  /// 작업 티켓을 conflict 상태로 변경한다.
  Future<void> markConflict(String ticketId, String reason);
}
