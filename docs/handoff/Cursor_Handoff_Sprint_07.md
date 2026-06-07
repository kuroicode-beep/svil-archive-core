# Cursor Handoff — Sprint 07 (Codex Important 반영 완료, 재검증 대기)

> **Sprint 06 기준 커밋**: `df0121e`
> **작업지시문**: [Notion Sprint 07](https://app.notion.com/p/378864048e5481c2b7ffe30733df6dd7)

## Sprint 07 완료 — MCP / Work Queue / Conflict Guard
- migration v5 (work_queue_tickets, mcp_tool_settings, permission_tokens)
- Work Queue service + Conflict Guard + MCP bridge status
- MCP tool registry (기본 off)
- Permission token service
- Work Queue UI panel
- Dashboard / Privacy / Footer MCP·queue 연동

## Sprint 08 권장 (Notion 작업지시문 확인)
- Ollama endpoint UI 설정
- 외부 API preflight
- TTS 정책

## 핵심 파일 (Sprint 07)
- `lib/data/db/migrations.dart`
- `lib/application/sac_container.dart`
- `lib/data/services/work_queue_service_impl.dart`
- `lib/data/services/conflict_guard_service_impl.dart`
- `lib/data/services/mcp_bridge_status_service_impl.dart`
- `lib/ui/screens/work_queue_panel.dart`
- `test/sprint7_integration_test.dart`

## Codex Important 반영
- `baseRevision` queue/conflict guard 전달
- permission token enqueue/approve enforcement
- stale MCP write → conflict ticket 테스트 추가

## 테스트
- `flutter test`: 56/56 passed
- MCP sidecar build: OK
