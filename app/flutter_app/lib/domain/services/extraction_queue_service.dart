// extraction_queue_service.dart — 추출 대기열 서비스 인터페이스

import '../models/personal_archive.dart';

abstract class ExtractionQueueService {
  /// 추출 대기열 후보를 조회한다.
  Future<List<ExtractionCandidate>> listPendingCandidates();

  /// 전체 후보를 상태별로 조회한다.
  Future<List<ExtractionCandidate>> listAllCandidates();

  /// mock/stub용 후보를 pending 상태로 추가한다 (자동 승인 없음).
  Future<ExtractionCandidate> enqueueCandidate(CreateExtractionCandidateInput input);

  /// 추출 후보를 승인하고 개인 아카이브 항목으로 이동한다.
  Future<PersonalArchiveItem> approveCandidate(String candidateId);

  /// 추출 후보를 수정 후 승인한다.
  Future<PersonalArchiveItem> editAndApproveCandidate(EditExtractionCandidateInput input);

  /// 추출 후보를 거절한다.
  Future<void> rejectCandidate(String candidateId);
}
