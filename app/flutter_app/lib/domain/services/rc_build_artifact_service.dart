// rc_build_artifact_service.dart — RC build artifact 기록 인터페이스

import '../models/rc_build_approval.dart';

abstract class RcBuildArtifactService {
  /// RC build artifact를 기록한다.
  Future<RcBuildArtifact> recordBuildArtifact({
    required String platform,
    required RcBuildType buildType,
    required String artifactPath,
    required String commitHash,
    required RcBuildArtifactStatus status,
    String? notes,
  });

  /// 기록된 RC build artifact 목록을 반환한다.
  Future<List<RcBuildArtifact>> listBuildArtifacts({int limit = 50});
}
