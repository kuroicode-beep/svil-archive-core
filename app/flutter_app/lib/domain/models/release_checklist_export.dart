// release_checklist_export.dart — RC 체크리스트 export 결과 모델

class ReleaseChecklistExportResult {
  final String relativePath;
  final String absolutePath;
  final String markdown;
  final int checkItemCount;

  const ReleaseChecklistExportResult({
    required this.relativePath,
    required this.absolutePath,
    required this.markdown,
    required this.checkItemCount,
  });
}
