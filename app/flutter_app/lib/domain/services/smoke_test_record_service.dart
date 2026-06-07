// smoke_test_record_service.dart — smoke test 기록 인터페이스

import '../models/smoke_test_record.dart';

abstract class SmokeTestRecordService {
  /// smoke test 기록을 생성한다.
  Future<SmokeTestRecord> createRecord({
    required String platform,
    required String checklistName,
    SmokeTestStatus status = SmokeTestStatus.pending,
    String? notes,
  });

  /// smoke test 기록을 갱신한다.
  Future<SmokeTestRecord> updateRecord({
    required String id,
    SmokeTestStatus? status,
    String? notes,
  });

  /// 최근 smoke test 기록을 조회한다.
  Future<SmokeTestRecord?> getLatestForPlatform(String platform);

  /// 전체 smoke test 기록을 조회한다.
  Future<List<SmokeTestRecord>> listRecords();
}
