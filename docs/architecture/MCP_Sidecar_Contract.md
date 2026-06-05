---
title: "SAC MCP Sidecar Contract"
author: "Claude Code (Sonnet)"
project: "SAC"
type: "MCP 계약"
status: "draft"
created: "2026-06-05"
---

# SAC MCP Sidecar Contract — Phase 1 Skeleton

---

## 확정 사항

| 항목 | 결정 |
|------|------|
| 구현 언어 | **TypeScript** |
| Transport | **stdio** (JSON-RPC over stdin/stdout) |
| 실행 방식 | Flutter 앱이 자식 프로세스로 시작/종료 |
| 폴더 위치 | `mcp/sidecar/` |
| 패키징 | `@modelcontextprotocol/sdk` 사용 예정 |

---

## 기본 Tool Contract (Phase 1 stub)

MCP sidecar가 외부 AI에게 노출하는 tool 목록:

```
list_documents       문서 목록 조회 (필터 포함)
get_document         단일 문서 조회 (메타 + 본문)
create_document      문서 생성 (write token 필요)
update_document      문서 수정 (write token + baseRevision 필요)
search_documents     FTS 검색
move_document_to_trash  문서 휴지통 이동 (destructive token 필요)
restore_document_from_trash  휴지통 복원 (write token 필요)
get_settings         앱 설정 조회
```

### 읽기 전용 tool (기본 허용)

- `list_documents`
- `get_document`
- `search_documents`
- `get_settings`

### 쓰기 tool (write token 필요)

- `create_document`
- `update_document`
- `restore_document_from_trash`

### 파괴적 tool (destructive token 필요)

- `move_document_to_trash`

---

## Tool 호출 예시

### list_documents

```json
{
  "name": "list_documents",
  "arguments": {
    "project": "SVIL",
    "type": "작업지시문",
    "limit": 20,
    "offset": 0
  }
}
```

### update_document

```json
{
  "name": "update_document",
  "arguments": {
    "id": "document-uuid",
    "content": "# 수정된 내용\n...",
    "base_revision": 5,
    "token": "write-token-uuid",
    "agent_id": "cursor-agent-01"
  }
}
```

---

## 에러 코드

| 코드 | 의미 |
|------|------|
| `CONFLICT` | baseRevision 불일치 — AI 덮어쓰기 방지 |
| `NO_TOKEN` | 필요한 권한 토큰 없음 |
| `TOKEN_EXPIRED` | 토큰 만료 |
| `NOT_FOUND` | 문서 없음 |
| `WORKSPACE_NOT_OPEN` | Workspace 미선택 상태 |

---

## Flutter ↔ Sidecar 연결

- Flutter `McpBridgeService`가 sidecar 프로세스 관리
- 플랫폼별 sidecar 실행 파일 경로는 플랫폼 어댑터로 분리
- macOS: `mcp/sidecar/dist/index.js` (node 실행)
- Windows: 동일 경로 (node.exe 경로 환경변수 기반)

---

## Phase 2+ 확장 예정 tool

```
get_personal_context       개인 아카이브 컨텍스트 조회
get_timeline               타임라인 조회
suggest_context_packet     AI context packet 생성
list_related_documents     관련 문서 목록
```

---

*Updated: 2026-06-05 | TypeScript + stdio 확정*
