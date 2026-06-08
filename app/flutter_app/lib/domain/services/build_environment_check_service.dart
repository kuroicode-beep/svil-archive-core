// build_environment_check_service.dart — 빌드 환경 점검 인터페이스

import '../models/build_environment_check.dart';

abstract class BuildEnvironmentCheckService {
  /// 빌드/실행 환경 점검을 실행하고 결과를 저장한다.
  Future<List<BuildEnvironmentCheck>> runChecks();

  /// 최근 점검 결과를 조회한다.
  Future<List<BuildEnvironmentCheck>> getLatestChecks();
}
