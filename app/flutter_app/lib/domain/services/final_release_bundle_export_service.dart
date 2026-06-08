// final_release_bundle_export_service.dart — Sprint 12 final release bundle 인터페이스

import '../models/rc_build_approval.dart';

abstract class FinalReleaseBundleExportService {
  /// 최종 RC release bundle을 export한다.
  Future<FinalReleaseBundleResult> exportFinalReleaseBundle();

  /// final bundle 생성 여부를 반환한다.
  Future<bool> hasFinalBundleExport();
}
