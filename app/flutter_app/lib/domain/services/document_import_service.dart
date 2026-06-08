// document_import_service.dart — 파일 Import 서비스 인터페이스

import '../models/document_import.dart';

abstract class DocumentImportService {
  /// workspace documents/ orphan 전체를 스캔한다.
  Future<ImportDryRunResult> scanWorkspaceOrphans(DocumentImportOptions options);

  /// 선택 경로 기준 후보를 스캔한다.
  Future<ImportDryRunResult> scanPaths(
    List<String> absolutePaths,
    DocumentImportOptions options,
  );

  /// dry-run preview를 반환한다.
  Future<ImportDryRunResult> dryRun(DocumentImportOptions options);

  /// 정식 등록을 실행한다 (dryRunOnly=false, backup 필수).
  Future<ImportExecutionResult> executeImport(DocumentImportOptions options);

  /// dry-run snapshot에 고정된 후보만 등록한다.
  Future<ImportExecutionResult> executeApprovedImport(ImportApprovedSnapshot snapshot);
}
