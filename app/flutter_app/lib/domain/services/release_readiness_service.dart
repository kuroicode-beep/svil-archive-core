// release_readiness_service.dart — RC 준비 상태 평가 인터페이스

import '../models/release_readiness.dart';

abstract class ReleaseReadinessService {
  /// RC 준비 상태를 평가하고 최근 결과를 저장한다.
  Future<ReleaseReadinessSummary> evaluate();

  /// 마지막 평가 결과를 조회한다.
  Future<ReleaseReadinessSummary?> getLatestSummary();
}
