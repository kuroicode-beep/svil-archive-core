// relay_journal_events.dart — Relay Layer sync_journal event type 상수

/// relay 이벤트에 document가 없을 때 사용하는 시스템 document id.
const String kRelaySystemDocumentId = '__relay_system__';

/// Sprint 01 relay journal event types (append-only action 값).
abstract final class RelayJournalEvents {
  static const relayTaskCreated = 'relay_task_created';
  static const relayTaskStarted = 'relay_task_started';
  static const relayTaskCompleted = 'relay_task_completed';
  static const relayTaskFailed = 'relay_task_failed';
  static const relayResultReceived = 'relay_result_received';
  static const relayResultRejected = 'relay_result_rejected';
  static const capsuleCreated = 'capsule_created';
  static const capsuleExpired = 'capsule_expired';
  static const capsuleDeleted = 'capsule_deleted';
  static const capsuleDeleteFailed = 'capsule_delete_failed';
  static const publicExportCreated = 'public_export_created';
  static const publicExportDeleted = 'public_export_deleted';
  static const manualRescueRequested = 'manual_rescue_requested';
  static const manualRescueApproved = 'manual_rescue_approved';
  static const manualRescueRejected = 'manual_rescue_rejected';
}
