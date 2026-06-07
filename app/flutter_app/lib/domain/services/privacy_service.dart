// privacy_service.dart — 개인정보 보호 요약 서비스 인터페이스

import '../models/dashboard.dart';

abstract class PrivacyService {
  /// 개인정보 보호 화면 요약을 조회한다.
  Future<PrivacySummary> getPrivacySummary();
}
