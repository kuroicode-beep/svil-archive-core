// report_consistency_service.dart — Sprint 보고서 정합성 검사 인터페이스

import '../models/report_consistency.dart';

abstract class ReportConsistencyService {
  /// 완료보고서 / handoff 커밋 해시 정합성을 검사한다.
  Future<ReportConsistencySummary> checkReports();
}
