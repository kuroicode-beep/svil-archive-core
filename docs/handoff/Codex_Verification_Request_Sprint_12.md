# Codex Verification Request — Sprint 12

> **Sprint 11 기준**: `5e02b31`
> **Sprint 12 구현 커밋**: `2e2e4da`
> **재작업 커밋**: (manifest·문서 동기화 후 갱신)
> **범위**: RC Build Approval / Smoke Approval / Tag Readiness / Final Bundle
> **작업지시문**: 채팅 WI (Notion 차단, 2026.06.08)

## 검증 항목

- [ ] migration v10 — 3 tables
- [ ] RC build artifact 기록 + path masking
- [ ] Release approval 보수 판정 (smoke pending ≠ ready_for_approval)
- [ ] SmokeApprovalService Windows/macOS
- [ ] RcTagReadinessService checklist
- [ ] FinalReleaseBundleExportService
- [ ] bundle에 개인 본문·secret/token 미포함
- [ ] Git tag 자동 생성 없음
- [ ] Dashboard RC final status
- [ ] Settings Release 섹션
- [ ] external API OFF / remote MCP OFF 유지
- [ ] Sprint 05~11 회귀
- [ ] `flutter analyze` / `flutter test` / MCP sidecar build
- [x] Git 커밋 (`2e2e4da`)
- [x] Cursor 자체 검증 — analyze / test 165 / sidecar build
- [x] `kSprintReportCommitManifest` Sprint 12 (`2e2e4da`) + RC 기준 Sprint 12
- [x] 완료보고서 / handoff / cursor.md 커밋 해시 정합 (재작업 후)
- [ ] Notion 완료보고서 (token 복구 시)

## 핵심 파일

- `lib/data/db/migrations.dart` (v10)
- `lib/domain/models/rc_build_approval.dart`
- `lib/domain/utils/release_approval_policy.dart`
- `lib/domain/utils/path_masking.dart`
- `lib/data/services/rc_build_artifact_service_impl.dart`
- `lib/data/services/release_approval_service_impl.dart`
- `lib/data/services/final_release_bundle_export_service_impl.dart`
- `lib/ui/screens/dashboard_screen.dart`
- `lib/ui/screens/settings_screen.dart`
- `test/sprint12_integration_test.dart`

## 실행 명령

```bash
cd app/flutter_app && flutter analyze && flutter test
cd mcp/sidecar && npm ci --ignore-scripts && npm run build
```
