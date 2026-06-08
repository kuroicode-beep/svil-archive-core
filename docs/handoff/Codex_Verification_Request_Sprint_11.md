# Codex Verification Request — Sprint 11

> **Sprint 10B 기준**: `9c47b7e`
> **Sprint 11 구현 커밋**: `2833494`
> **범위**: RC Finalization / Smoke Confirmation / Release Notes
> **작업지시문**: [Notion Sprint 11](https://app.notion.com/p/379864048e54818bbf46fd13a22a420e)

## 검증 항목

- [ ] migration v9 — `verification_pass_records`
- [ ] `RcFinalizationStatus` 보수 판정 (smoke pending ≠ ready)
- [ ] `VerificationPassRecordService` — analyze/test/sidecar_build
- [ ] commit mismatch → warning
- [ ] `ReleaseFinalizationExportService` — release notes / known issues / tag checklist
- [ ] export에 개인 본문·secret/token 미포함
- [ ] Git tag 자동 생성 없음
- [ ] Dashboard RC Finalization 카드
- [ ] Settings Release 섹션 export 버튼
- [ ] Privacy release policy 표시
- [ ] external API OFF / remote MCP OFF 유지
- [ ] Sprint 05~10B 회귀
- [ ] `flutter analyze` / `flutter test` / MCP sidecar build
- [x] Git 커밋 (`2833494`) / Notion 완료보고서
- [x] `kSprintReportCommitManifest` Sprint 11 (`2833494`)
- [x] Cursor 자체 검증 — analyze / test 147 / sidecar build

## 핵심 파일

- `lib/data/db/migrations.dart` (v9)
- `lib/domain/models/rc_finalization.dart`
- `lib/domain/utils/rc_finalization_policy.dart`
- `lib/data/services/verification_pass_record_service_impl.dart`
- `lib/data/services/release_finalization_export_service_impl.dart`
- `lib/data/services/release_readiness_service_impl.dart`
- `lib/ui/screens/settings_screen.dart`
- `lib/ui/screens/dashboard_screen.dart`
- `lib/ui/screens/privacy_screen.dart`
- `test/sprint11_integration_test.dart`

## 실행 명령

```bash
cd app/flutter_app && flutter analyze && flutter test
cd mcp/sidecar && npm ci --ignore-scripts && npm run build
```
