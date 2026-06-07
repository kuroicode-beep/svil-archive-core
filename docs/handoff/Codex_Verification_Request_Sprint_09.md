# Codex Verification Request — Sprint 09 (재검증)

> **Sprint 08 기준 커밋**: `36e9d6c`
> **Sprint 09 구현 커밋**: `a15a4c1`
> **Codex 1차 검증**: 부분완료 — B1 + B2 + I1 + I2 → 재작업 완료
> **범위**: Integrity Hardening / Execution Recovery / macOS Smoke
> **작업지시문**: [Notion Sprint 09](https://app.notion.com/p/378864048e5481d5a3cbd8c1dd7fcd6f)

## 검증 항목

- [x] migration v7 — integrity/smoke tables + work_queue recovery columns
- [x] integrity scan detects orphan Markdown
- [x] integrity scan detects stale DB row
- [x] scan does not auto-delete orphan files
- [x] `create_document` orphan overwrite blocked (`orphan_file_exists`)
- [x] recovery assessment for failed / blocked / conflict tickets
- [x] recovery ticket creation (`source_ticket_id`, `recovery_kind`)
- [x] source failed ticket not re-executed directly
- [x] recovery preview without sensitive body
- [x] report consistency manifest check
- [x] report mismatch detection (app_settings)
- [x] report consistency local docs/reports+handoff 검사 (I2 재작업)
- [x] integrity scan includes report mismatch items
- [x] macOS smoke test record create/list
- [x] Dashboard integrity / report / smoke summary
- [x] Privacy integrity summary + policy UI
- [x] Work Queue recovery badge + preview/create buttons
- [x] Integrity screen (scan, open items, smoke record)
- [x] Sprint 07 MCP enqueue-only 회귀
- [x] Sprint 08 approved-only / baseRevision 회귀
- [x] Sprint 05/06 회귀
- [x] 접근성: 50px 버튼, 16px 폰트
- [x] Sprint 09 Git 커밋 존재 (B1 재작업)
- [x] Notion Cursor 완료보고서 존재 (B2 재작업)
- [x] 핸드오프 Notion 링크 정정 (I1 재작업)
- [x] `flutter analyze` / `flutter test` (105/105) / MCP sidecar build

## 핵심 파일

- `lib/data/db/migrations.dart` (v7)
- `lib/data/services/workspace_integrity_service_impl.dart`
- `lib/data/services/workspace_file_inventory_service_impl.dart`
- `lib/data/services/execution_recovery_service_impl.dart`
- `lib/data/services/smoke_test_record_service_impl.dart`
- `lib/data/services/report_consistency_service_impl.dart`
- `lib/data/services/safe_apply_service_impl.dart`
- `lib/application/sac_container.dart`
- `lib/ui/screens/integrity_screen.dart`
- `lib/ui/screens/work_queue_panel.dart`
- `lib/ui/screens/dashboard_screen.dart`
- `lib/ui/widgets/privacy_status_panel.dart`
- `test/sprint9_integration_test.dart`

## 실행 명령

```bash
cd app/flutter_app && flutter analyze && flutter test
cd mcp/sidecar && npm ci --ignore-scripts && npm run build
```
