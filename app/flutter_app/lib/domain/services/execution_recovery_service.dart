// execution_recovery_service.dart — 실행 티켓 복구 인터페이스

import '../models/execution_recovery.dart';
import '../models/ticket_execution.dart';
import '../models/work_queue.dart';

abstract class ExecutionRecoveryService {
  /// 실패한 실행 티켓의 복구 가능성을 평가한다.
  Future<RecoveryAssessment> assessTicket(String ticketId);

  /// 복구용 dry-run preview를 생성한다.
  Future<DryRunPreview> createRecoveryPreview(String ticketId);

  /// 복구용 새 작업 티켓을 생성한다.
  Future<WorkQueueTicket> createRecoveryTicket(String sourceTicketId);
}
