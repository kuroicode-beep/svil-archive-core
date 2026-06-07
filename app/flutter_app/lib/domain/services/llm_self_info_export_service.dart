// llm_self_info_export_service.dart — LLM 자기정보 문서 export 인터페이스

import '../models/dashboard.dart';

class LlmSelfInfoExportOptions {
  final List<String> journalCommentIds;

  const LlmSelfInfoExportOptions({this.journalCommentIds = const []});
}

abstract class LlmSelfInfoExportService {
  /// active 개인 아카이브만 포함한 preview Markdown을 생성한다.
  Future<LlmSelfInfoExportResult> buildPreview({LlmSelfInfoExportOptions? options});

  /// preview를 workspace exports 경로에 저장한다.
  Future<LlmSelfInfoExportResult> exportToFile({LlmSelfInfoExportOptions? options});
}
