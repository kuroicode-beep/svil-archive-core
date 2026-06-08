// smoke_approval_service.dart — Windows/macOS smoke approval 인터페이스

import '../models/rc_build_approval.dart';
import '../models/smoke_test_record.dart';

abstract class SmokeApprovalService {
  /// 플랫폼 smoke approval 상태를 갱신한다.
  Future<SmokeTestRecord> updateSmokeApproval({
    required String platform,
    required SmokeTestStatus status,
    String? notes,
  });

  /// smoke approval 요약을 반환한다.
  Future<SmokeApprovalSummary> getSmokeApprovalSummary();
}
