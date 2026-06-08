# Cursor Handoff — Sprint 14 MCP Archive Service Integration

> **Sprint 13 기준**: `efa97e2` / HEAD `433ede5`
> **작업지시문**: [Sprint 14 WI](https://app.notion.com/p/379864048e5481c19ca5c2a50e89bdb3)

## Sprint 14 구현 요약

- `mcp/sidecar/src/archive/` — workspace resolve, SQLite reader, markdown fallback
- Read-only tools: `get_workspace_status`, `get_settings`, `list_documents`, `get_document`, `search_documents`
- Write/destructive tools → `QUEUE_APPROVAL_REQUIRED`
- `SAC_WORKSPACE_ROOT` 필수, 없으면 `SAC_WORKSPACE_ROOT_NOT_FOUND`
- SQLite 우선, 없으면 `markdown_scan` fallback
- `.cursor/mcp.json` + `docs/handoff/Cursor_MCP_Setup_Sprint_14.md`
- `mcp/sidecar/test/archive.test.ts` (8항목)
- Sprint 13 startup fix: `initializeEarly` / `activateFromSettings`

## Codex에게

- stub JSON 제거 여부
- 실제 workspace 데이터 응답
- full body 기본 금지
- absolute path / secret masking
- `npm test` + `flutter test`

## 소장님 Cursor smoke

1. `SAC_WORKSPACE_ROOT` 설정 확인
2. `get_workspace_status` → `documentCount` > 0
3. `list_documents` → `relativePath` 목록
4. `search_documents` → 실제 검색 결과
