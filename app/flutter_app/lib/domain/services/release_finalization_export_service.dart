// release_finalization_export_service.dart — Sprint 11 RC 문서 export 인터페이스

import '../models/rc_finalization.dart';

abstract class ReleaseFinalizationExportService {
  /// release notes Markdown을 export한다.
  Future<ReleaseMarkdownExportResult> exportReleaseNotes();

  /// known issues Markdown을 export한다.
  Future<ReleaseMarkdownExportResult> exportKnownIssues();

  /// v0.1 RC tag readiness checklist를 export한다.
  Future<ReleaseMarkdownExportResult> exportTagReadinessChecklist();

  /// export 생성 여부를 조회한다.
  Future<ReleaseExportStatus> getExportStatus();
}
