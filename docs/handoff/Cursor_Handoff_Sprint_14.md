# Cursor Handoff — Sprint 14 MCP Archive Service Integration

> **Sprint 14 구현 커밋**: `439a0bd`
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

## Codex 재작업 (native binding blocker)

- **원인**: `npm ci --ignore-scripts`가 `better-sqlite3` install script를 건너뛰어 `better_sqlite3.node` 미생성
- **수정**: `scripts/package_windows_rc.ps1` — `Install-SidecarDependencies` (`npm ci` + `npm rebuild better-sqlite3` + `.node` 파일 검증)
- **sidecar**: `verify:native` 테스트 추가, `npm test`에 포함
- **문서**: Codex/Cursor MCP setup에서 `--ignore-scripts` 제거

## Codex에게

- stub JSON 제거 여부
- clean install: `npm ci && npm run build && npm test` (8/8 + native verify)
- Windows package `mcp_sidecar_native_binding_included: true`
- full body 기본 금지
- absolute path / secret masking
- `flutter test`

## 소장님 Cursor smoke

1. `SAC_WORKSPACE_ROOT` 설정 확인
2. `get_workspace_status` → workspace/index 연결 성공 (문서 0건이면 index 미동기화 가능)
3. `list_documents` → `relativePath` 목록
4. `search_documents` → 실제 검색 결과
