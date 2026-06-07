# Codex Verification Request — Sprint 06

## 검증 대상
- Sprint 06 AI Dashboard / Privacy
- 기준 커밋: (Sprint 06 구현 커밋)
- 브랜치: `master`
- Sprint 05 기준: `c37c8ac`

## 검증 항목

### 기능
- [ ] 대시보드 화면 접근 및 실데이터 요약 표시
- [ ] 개인정보 보호 화면 접근 및 상태 표시
- [ ] AI 협업 프로토콜 현황 패널
- [ ] LLM self-info export — active만 포함
- [ ] pending/rejected/deleted export 제외
- [ ] Local AI offline/error 안전 처리
- [ ] 외부 API 호출 없음
- [ ] 자동 승인 없음

### 회귀
- [ ] Sprint 05 승인 원자성 유지
- [ ] Sprint 03/04/05 테스트 회귀

### 테스트
- [ ] `flutter analyze` / `flutter test` / MCP sidecar build

## 핵심 파일
- `lib/data/services/dashboard_service_impl.dart`
- `lib/data/services/privacy_service_impl.dart`
- `lib/data/services/llm_self_info_export_service_impl.dart`
- `lib/data/services/ollama_adapter.dart`
- `lib/ui/screens/dashboard_screen.dart`
- `lib/ui/screens/privacy_screen.dart`
- `test/sprint6_integration_test.dart`
