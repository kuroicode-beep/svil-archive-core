# Codex Verification Request — Sprint 14

> **Sprint 14 구현 커밋**: `439a0bd`
> **작업지시문**: [Sprint 14](https://app.notion.com/p/379864048e5481c19ca5c2a50e89bdb3)
> **범위**: MCP sidecar → SAC Archive / SQLite read-only integration

## 검증 항목

- [ ] stub JSON 제거 — read-only tools 실제 데이터
- [ ] `SAC_WORKSPACE_ROOT` 미설정 오류
- [ ] SQLite / markdown_scan 분기
- [ ] `get_workspace_status`, `get_settings`, `list_documents`, `get_document`, `search_documents`
- [ ] full body 기본 금지
- [ ] absolute path masking
- [ ] secret/token masking
- [ ] `external_api_enabled` / `remote_mcp_enabled` false
- [ ] write tools `QUEUE_APPROVAL_REQUIRED`
- [ ] `npm test` (sidecar)
- [ ] `flutter analyze` / `flutter test`
- [ ] Sprint 05~13 회귀
- [ ] Cursor MCP smoke 문서화

## 실행 명령

```bash
cd mcp/sidecar && npm ci && npm run build && npm test
cd app/flutter_app && flutter analyze && flutter test
```

`npm test`는 `verify:native`로 `better_sqlite3.node` 존재와 in-memory DB open을 먼저 확인합니다.  
Windows 패키징은 `scripts/package_windows_rc.ps1`이 `npm rebuild better-sqlite3`와 native binding 파일 검증을 수행합니다.

## 핵심 파일

- `mcp/sidecar/src/archive/archive_service.ts`
- `mcp/sidecar/src/tools/handler.ts`
- `mcp/sidecar/test/archive.test.ts`
- `.cursor/mcp.json`
- `docs/handoff/Cursor_MCP_Setup_Sprint_14.md`
