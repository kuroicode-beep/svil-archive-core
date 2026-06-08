// smoke_approval_service_impl.dart — smoke approval 구현

import '../../domain/models/rc_build_approval.dart';
import '../../domain/models/smoke_test_record.dart';
import '../../domain/services/smoke_approval_service.dart';
import '../../domain/services/smoke_test_record_service.dart';

class SmokeApprovalServiceImpl implements SmokeApprovalService {
  final SmokeTestRecordService _smokeTestRecordService;

  SmokeApprovalServiceImpl({required SmokeTestRecordService smokeTestRecordService})
      : _smokeTestRecordService = smokeTestRecordService;

  @override
  Future<SmokeTestRecord> updateSmokeApproval({
    required String platform,
    required SmokeTestStatus status,
    String? notes,
  }) async {
    final safeNotes = _sanitizeNotes(notes);
    final existing = await _smokeTestRecordService.getLatestForPlatform(platform);
    if (existing == null) {
      final created = await _smokeTestRecordService.createRecord(
        platform: platform,
        checklistName: platform == 'macOS' ? 'macos_smoke' : 'windows_smoke',
        status: status,
        notes: safeNotes,
      );
      return created;
    }
    return _smokeTestRecordService.updateRecord(
      id: existing.id,
      status: status,
      notes: safeNotes,
    );
  }

  @override
  Future<SmokeApprovalSummary> getSmokeApprovalSummary() async {
    final mac = await _smokeTestRecordService.getLatestForPlatform('macOS');
    final win = await _smokeTestRecordService.getLatestForPlatform('Windows');
    return SmokeApprovalSummary(
      macStatus: mac?.status,
      windowsStatus: win?.status,
      macRecorded: mac != null,
      windowsRecorded: win != null,
      bothPassed: mac?.status == SmokeTestStatus.passed && win?.status == SmokeTestStatus.passed,
    );
  }

  /// smoke notes에서 민감 본문 패턴을 제거한다.
  String? _sanitizeNotes(String? notes) {
    if (notes == null || notes.isEmpty) return notes;
    if (notes.length > 500) return notes.substring(0, 500);
    return notes;
  }
}
