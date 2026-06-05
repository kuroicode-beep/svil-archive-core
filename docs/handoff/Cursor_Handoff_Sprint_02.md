---
title: "Cursor Handoff — SAC Sprint 02"
author: "Claude Code (Sonnet)"
project: "SAC — SVIL Archive Core"
type: "핸드오프"
status: "ready"
created: "2026-06-05"
next_agent: "Cursor"
---

# Cursor Handoff — SAC Sprint 02

작성일: 2026-06-05
작성자: Claude Code (Sonnet) — 작업지시문 01 완료 후 작성
대상: Cursor

---

## 1. 인계 개요

Sprint 01 (Sonnet Architecture Skeleton) 완료.
Cursor는 이 문서를 기반으로 Sprint 02 기능 구현을 시작합니다.

---

## 2. 구현된 것 (Sonnet Sprint 01)

### 폴더 구조

```
project_root/
├── app/flutter_app/          Flutter Desktop 앱 skeleton
├── mcp/sidecar/              TypeScript MCP sidecar stub
├── packages/                 빈 패키지 폴더 (추후 분리용)
├── asset/design/             디자인 소스 폴더 + README
├── docs/architecture/        아키텍처 문서 6종
├── docs/handoff/             이 문서
├── test_fixtures/sample_workspace/  테스트용 Workspace 폴더
└── scripts/                  빈 폴더
```

### Flutter 앱 (분석 오류 0개)

- `lib/domain/models/`: Workspace, Document, SyncState, TrashItem, AppSettings, ThemeSettings, TtsSettings, McpToolDefinition, PermissionToken, WorkTicket, PersonalArchiveCandidate
- `lib/domain/services/`: WorkspaceService, ArchiveService, SearchService, SyncService, SettingsService, ThemeService, TtsService, McpBridgeService (모두 abstract)
- `lib/ui/theme/app_theme.dart`: Light / Dark / HighContrast 테마 토큰
- `lib/ui/screens/welcome_screen.dart`: Workspace 선택 placeholder
- `lib/ui/screens/main_shell.dart`: 3패널 placeholder (좌/중/우)
- `lib/ui/widgets/left_sidebar.dart`: 10개 메뉴 목록 placeholder
- `lib/ui/widgets/right_context_panel.dart`: TTS 컨트롤 stub
- `lib/ui/widgets/footer_bar.dart`: 고대비 토글 고정 배치
- `lib/main.dart`: SacApp (Light 기본 테마)

### MCP Sidecar

- `mcp/sidecar/package.json` + `tsconfig.json`
- `src/index.ts`: stdio transport stub
- `src/tools/definitions.ts`: 8개 tool 정의
- `src/tools/handler.ts`: stub 핸들러

### 아키텍처 문서

- `docs/architecture/Architecture_Note.md`
- `docs/architecture/Module_Map.md`
- `docs/architecture/Service_Contract.md`
- `docs/architecture/SQLite_Schema_Draft.md`
- `docs/architecture/MCP_Sidecar_Contract.md`
- `docs/architecture/Design_Asset_Rules.md`

---

## 3. 구현하지 않은 것 (Cursor Sprint 02+ 담당)

| 항목 | 우선순위 |
|------|----------|
| SQLite DB 실제 초기화 코드 (WAL 모드, migration) | 높음 |
| WorkspaceService 구현체 (DB + 파일시스템) | 높음 |
| ArchiveService 구현체 (Markdown CRUD) | 높음 |
| SyncService 구현체 (파일 watcher, revision 관리) | 높음 |
| FTS5 인덱싱 구현 | 높음 |
| 기본 Document Editor UI | 중간 |
| 폴더 트리 실제 구현 | 중간 |
| ThemeService 실제 상태 연결 | 중간 |
| MCP sidecar 실제 ArchiveService 연결 | 중간 |
| TTS 실제 엔진 연결 (시스템 TTS) | 낮음 |
| 벡터 검색 (Phase 3) | 낮음 |

---

## 4. 다음 작업 추천 순서

1. `data/db/` — SQLite 초기화, migration, WAL 설정
2. `data/file/` — Markdown 파일 CRUD, frontmatter 파싱
3. `WorkspaceService` 구현체 연결
4. `ArchiveService` 구현체 연결
5. `SyncService` 파일 watcher + revision 관리
6. FTS5 인덱싱
7. WelcomeScreen → MainShell 전환 로직
8. 폴더 트리 실제 구현

---

## 5. 주의사항

- **Windows 절대경로 하드코딩 금지**: 경로 처리는 항상 플랫폼 어댑터 사용
- **UI에서 DB 직접 접근 금지**: 반드시 service 인터페이스 경유
- **MCP sidecar에서 ArchiveService 우회 금지**
- **AI 덮어쓰기 방지**: `updateDocument`에서 반드시 revision 검증
- **개인 아카이브 자동 승인 금지**: Phase 1에서 전부 수동 승인
- **sync_journal**: Phase 1에서 복구 엔진 없음, append-only 기록만

---

## 6. macOS 검증 체크리스트

Sprint 02 완료 전 확인 필요:
- [ ] `flutter build macos` 성공
- [ ] 경로 하드코딩 없음
- [ ] `.sac/` 폴더 생성이 상대경로로 동작

---

## 7. Codex 검증 포인트

Cursor Sprint 02 완료 후 Codex가 확인할 항목:
- revision 기반 충돌 방지 로직 정확성
- SQLite WAL 모드 설정 여부
- Markdown frontmatter 파싱 정확성
- 경로 처리 플랫폼 중립성
- 개인 아카이브 자동 승인 경로 없음 확인

---

*SVIL — Singularity Visual Intelligence Lab | Sprint 01 → Sprint 02 Handoff*
