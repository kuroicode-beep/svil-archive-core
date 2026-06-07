// safe_apply_service.dart — Markdown safe apply 서비스 인터페이스

import '../models/ticket_execution.dart';

abstract class SafeApplyService {
  /// Markdown 문서를 안전하게 생성한다.
  Future<SafeApplyResult> createDocument(SafeCreateDocumentRequest request);

  /// Markdown 문서를 안전하게 수정한다.
  Future<SafeApplyResult> updateDocument(SafeUpdateDocumentRequest request);

  /// Markdown 문서를 휴지통으로 이동한다 (영구 삭제 아님).
  Future<SafeApplyResult> moveDocumentToTrash(SafeTrashDocumentRequest request);
}
