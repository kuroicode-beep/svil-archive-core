# Cursor MCP Setup — SAC Archive (Sprint 14)

## 개발 repo

프로젝트 루트 `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "sac-archive": {
      "command": "C:\\Program Files\\nodejs\\node.exe",
      "args": ["dist/index.js"],
      "cwd": "C:\\Projects\\svil-archive-core\\mcp\\sidecar",
      "env": {
        "SAC_WORKSPACE_ROOT": "C:\\Users\\kuroi\\OneDrive\\문서\\SAC DOCS"
      }
    }
  }
}
```

## 패키지 portable

```json
{
  "mcpServers": {
    "sac-archive": {
      "command": "C:\\Program Files\\nodejs\\node.exe",
      "args": ["dist/index.js"],
      "cwd": "C:\\Projects\\svil-archive-core\\bin\\windows\\sac_v0.1.0-rc.1_windows_x64_<commit>\\mcp\\sidecar",
      "env": {
        "SAC_WORKSPACE_ROOT": "<SAC_DOCS_PATH>"
      }
    }
  }
}
```

## Cursor smoke

1. Cursor 재시작
2. Settings → MCP → `sac-archive` Connected
3. Tool 호출:
   - `get_workspace_status`
   - `list_documents`
   - `search_documents`
4. stub JSON이 아닌 실제 `documentCount` / `relativePath` 확인

## 필수 환경

- Node.js 18+
- `SAC_WORKSPACE_ROOT` — SAC DOCS workspace 폴더
- sidecar build: `cd mcp/sidecar && npm ci && npm run build && npm run verify:native`

`better-sqlite3`는 native binding이 필요합니다. install script를 건너뛰지 마세요.  
clean install 검증: `npm ci && npm run build && npm test`
