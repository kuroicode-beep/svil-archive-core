// release_checklist_export_service.dart — RC 체크리스트 Markdown export 인터페이스

import '../models/release_checklist_export.dart';

abstract class ReleaseChecklistExportService {
  /// RC 체크리스트 Markdown을 생성하고 workspace에 저장한다.
  Future<ReleaseChecklistExportResult> exportToFile();
}
