// workspace_integrity_service.dart — workspace 무결성 검사 인터페이스

import '../models/integrity_scan.dart';

abstract class WorkspaceIntegrityService {
  /// Workspace 전체 무결성 검사를 실행한다.
  Future<IntegrityScanRun> runScan();

  /// 최근 무결성 검사 요약을 조회한다.
  Future<IntegritySummary> getLatestSummary();

  /// 열린 무결성 이슈 목록을 조회한다.
  Future<List<IntegrityScanItem>> listOpenItems();

  /// 무결성 이슈 상태를 갱신한다.
  Future<void> updateItemStatus(String itemId, IntegrityItemStatus status);
}
