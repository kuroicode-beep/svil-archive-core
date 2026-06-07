// dashboard_service.dart — 대시보드 요약 서비스 인터페이스

import '../models/dashboard.dart';

abstract class DashboardService {
  /// 대시보드 전체 요약을 조회한다.
  Future<DashboardSummary> getDashboardSummary();
}
