// rc_tag_readiness_service.dart — v0.1.0-rc.1 tag readiness 인터페이스

import '../models/rc_build_approval.dart';

abstract class RcTagReadinessService {
  /// RC tag readiness 체크를 실행하고 기록한다.
  Future<RcTagReadinessSummary> runRcTagReadinessChecks();

  /// 최신 tag readiness 실행 결과를 반환한다.
  Future<RcTagReadinessSummary?> getLatestSummary();
}
