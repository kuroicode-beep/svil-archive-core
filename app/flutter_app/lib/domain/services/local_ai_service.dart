// local_ai_service.dart — 로컬 AI 연결 서비스 인터페이스

import '../models/dashboard.dart';

abstract class LocalAiService {
  /// 로컬 AI 연결 상태를 확인한다.
  Future<LocalAiStatus> checkStatus();

  /// 사용 가능한 로컬 모델 목록을 조회한다.
  Future<List<LocalAiModel>> listModels();
}
