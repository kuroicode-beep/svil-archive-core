---
title: "SAC Architecture Note"
author: "Claude Code (Sonnet)"
project: "SAC — SVIL Archive Core"
type: "아키텍처 설계"
status: "draft"
created: "2026-06-05"
phase: "Phase 1 Skeleton"
---

# SAC Architecture Note — Phase 1 Skeleton

작성일: 2026-06-05
작성자: Claude Code (Sonnet)
작업지시문: Dev_20260605_SAC_Work_Instruction_01_Sonnet_Architecture_v1_Lumi

---

## 1. 전체 구조 원칙

```
Markdown = Source of Truth
SQLite   = Index / Context / Search Brain
MCP      = AI Communication Protocol
UI       = Flutter Desktop (Windows 우선, macOS 포팅 가능)
MCP Sidecar = TypeScript (stdio transport)
```

### 핵심 불변 원칙

- Markdown 파일은 원본이다. SQLite는 절대 원본을 대체하지 않는다.
- SQLite가 손상되더라도 Markdown Workspace 재스캔으로 완전 재생성 가능해야 한다.
- 사용자 직접 수정본이 AI 수정보다 항상 우선한다.
- AI는 사용자 승인 없이 문서를 덮어쓸 수 없다.
- 개인 데이터는 기본적으로 로컬에서만 처리한다.
- 백엔드 없이 로컬만으로 기본 동작이 완료되어야 한다.

---

## 2. Markdown ↔ SQLite ↔ MCP 관계

```
[Markdown Files]
      ↓ (파일 watcher / 재스캔)
[SyncService]
      ↓
[SQLite DB (.sac/sac.sqlite)]
   ├─ documents (인덱스)
   ├─ document_fts (전문 검색)
   ├─ sync_state (동기화 상태)
   ├─ sync_journal (이벤트 로그, Phase 1: append-only)
   └─ work_tickets, permission_tokens (Phase 1 placeholder)
      ↑
[ArchiveService] ← UI 와 MCP sidecar 모두 이 서비스 경계를 사용
      ↑
[MCP TypeScript Sidecar] (stdio) ← AI 에이전트(Claude, Cursor 등)
```

---

## 3. Flutter ↔ MCP Sidecar 관계

- Flutter 앱이 sidecar 프로세스를 자식 프로세스로 시작/종료한다.
- 통신은 stdio (JSON-RPC over stdin/stdout) 사용.
- McpBridgeService가 Flutter에서 sidecar 프로세스를 관리한다.
- sidecar는 ArchiveService와 동일한 인터페이스를 통해 문서에 접근한다.
- sidecar가 SQLite나 파일을 직접 무질서하게 조작하면 안 된다.

---

## 4. Phase 1 최소 구현 범위

### 포함

- Flutter Desktop Windows 앱 skeleton (빌드 가능)
- 3패널 placeholder UI
- 도메인 모델 (Dart)
- 서비스 인터페이스 (Dart abstract class)
- SQLite schema draft (migration 파일)
- MCP sidecar 폴더 구조 + tool contract 문서
- asset/design/ 폴더 + 규칙 문서
- Markdown frontmatter 최소 정책 문서
- Cursor Handoff 문서

### 제외 (Phase 2+ 구현)

- 완성된 문서 편집기
- 완성된 MCP 서버 동작
- 완성된 개인 아카이브 기능
- 외부 API 실제 연동 (Ollama, DeepSeek)
- TTS 실제 엔진
- 벡터 검색
- 고급 sync 복구 엔진
- 개인 데이터 자동 승인 (Phase 1: 전부 수동 승인)

---

## 5. macOS Smoke Test 항목

Phase 1 완료 후 macOS 검증 체크리스트:

- [ ] `flutter build macos` 오류 없이 완료
- [ ] 경로 처리 로직에 Windows 하드코딩(`\`, `C:\`) 없음
- [ ] Workspace path adapter 플랫폼 분기 확인
- [ ] MCP sidecar 실행 경로가 플랫폼 어댑터로 분리 가능한지 확인
- [ ] `.sac/sac.sqlite` 경로가 상대경로 기준으로 생성 가능한지 확인

---

## 6. 중요 결정 사항

| 항목 | 결정 | 이유 |
|------|------|------|
| MCP sidecar 언어 | TypeScript | 루미 지시 확정 |
| MCP transport | stdio | 로컬 우선, 외부 노출 없음 |
| SQLite 모드 | WAL | 동시 읽기 성능 |
| sync_journal Phase 1 | append-only 기록만 | 정밀 복구 엔진은 Phase 2 |
| 개인 아카이브 자동 승인 | 금지 (Phase 1) | 프라이버시 원칙 |
| 기본 테마 | Friendly Light | 루미 지시 |
| 고대비 토글 위치 | 하단 footer 고정 | 접근성 |

---

*SVIL — Singularity Visual Intelligence Lab / Phase 1 Skeleton / 2026-06-05*
