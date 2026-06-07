# Codex Verification Request — Sprint 05

## 검증 대상
- Sprint 05 Personal Archive / Extraction Queue
- 기준 커밋: (Sprint 05 구현 커밋)
- 브랜치: `master`

## 검증 항목

### 기능
- [ ] migration v4 테이블 생성
- [ ] 개인 아카이브 수동 생성/수정/삭제
- [ ] 추출 후보 pending → 승인 시 `personal_archive_items` 저장
- [ ] 수정 후 승인 / 거절 흐름
- [ ] 승인 전 후보가 개인 아카이브에 저장되지 않음
- [ ] 자동 승인 로직 없음
- [ ] 로그에 개인 데이터 본문 미포함

### 회귀
- [ ] Sprint 03/04 테스트 회귀
- [ ] category path source of truth 정책 유지

### 테스트
- [ ] `flutter analyze` / `flutter test` / MCP sidecar build

## 핵심 파일
- `lib/data/db/migrations.dart` (v4)
- `lib/data/services/personal_archive_service_impl.dart`
- `lib/data/services/extraction_queue_service_impl.dart`
- `lib/ui/screens/personal_archive_panel.dart`
- `lib/ui/screens/extraction_queue_panel.dart`
- `test/sprint5_integration_test.dart`
