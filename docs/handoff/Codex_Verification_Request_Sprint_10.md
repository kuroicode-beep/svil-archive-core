# Codex Verification Request — Sprint 10

> **Sprint 09 기준 커밋**: `cd684a2`
> **Sprint 10 구현 커밋**: (미커밋 — Cursor 자체 검증 시점)
> **범위**: RC / Smoke / Packaging Readiness
> **작업지시문**: [Notion Sprint 10](https://app.notion.com/p/379864048e5481499f62ea09b10524a5)
> **Cursor 자체 검증**: 2026.06.08 — analyze/test/sidecar PASS

## 검증 항목

- [ ] migration v8 — `release_readiness_checks`, `build_environment_checks`
- [ ] `BuildEnvironmentCheckService` — schema/DB/workspace/sidecar/platform
- [ ] `ReleaseReadinessService` — evaluate + getLatestSummary
- [ ] RC readiness — external API OFF, MCP local-only, smoke/report/integrity 집계
- [ ] `ReleaseChecklistExportService` — `.sac/exports/release_checklist_*.md`
- [ ] Settings 화면 — Workspace/Appearance/Local AI/MCP/Privacy/Integrity/Release/About
- [ ] `SacSection.settings` 사이드바 라우팅
- [ ] Ollama endpoint 저장 + `updateOllamaEndpoint`
- [ ] Dashboard RC Readiness 카드
- [ ] Integrity — Windows smoke + PASS/FAIL/SKIP
- [ ] Privacy / Work Queue — RC blocking 요약
- [ ] MCP sidecar dist 자동 탐지 (`resolveMcpSidecarDistPath`)
- [ ] `kSprintReportCommitManifest` Sprint 09 (`cd684a2`)
- [ ] 구현 금지 — 자동 배포/코드서명/notarization/외부API/remote MCP 미포함
- [ ] Sprint 05~09 회귀
- [ ] 접근성 — 50px 버튼, 16px 폰트 (Settings/Integrity)
- [ ] **Sprint 10 Git 커밋 존재**
- [ ] **Notion Cursor 완료보고서 존재**
- [ ] `flutter analyze` No issues
- [ ] `flutter test` (126/126) / MCP sidecar build

## 핵심 파일

- `lib/data/db/migrations.dart` (v8)
- `lib/domain/models/release_readiness.dart`
- `lib/domain/models/build_environment_check.dart`
- `lib/data/services/release_readiness_service_impl.dart`
- `lib/data/services/build_environment_check_service_impl.dart`
- `lib/data/services/release_checklist_export_service_impl.dart`
- `lib/ui/screens/settings_screen.dart`
- `lib/application/sac_container.dart`
- `lib/ui/screens/dashboard_screen.dart`
- `lib/ui/screens/integrity_screen.dart`
- `lib/ui/screens/privacy_screen.dart`
- `lib/ui/screens/work_queue_panel.dart`
- `lib/ui/widgets/left_sidebar.dart`
- `test/sprint10_integration_test.dart`

## 실행 명령

```bash
cd app/flutter_app && flutter analyze && flutter test
cd mcp/sidecar && npm ci --ignore-scripts && npm run build
```

## Cursor 자체 검증 결과 (2026.06.08)

| 항목 | 결과 |
|------|------|
| `flutter analyze` | No issues |
| `flutter test` | **126/126** passed (Sprint 10: 21항목) |
| MCP sidecar build | PASS |
| Git 커밋 | ⚠️ 미커밋 |
| Notion 완료보고서 | ✅ [등록됨](https://app.notion.com/p/379864048e54812ebd56de656a0cd051) |
