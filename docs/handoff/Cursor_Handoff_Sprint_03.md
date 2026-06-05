---
title: "Cursor Handoff — Sprint 03"
author: "Cursor"
project: "SAC"
type: "핸드오프"
created: "2026-06-06"
next_agent: "Cursor"
---

# Cursor Handoff — SAC Sprint 03 (Document Archive)

## Sprint 02에서 완료된 것
- Workspace 생성/열기 + 폴더 구조
- Markdown CRUD (create/read/update) + frontmatter
- SQLite WAL + documents/sync_state/sync_journal
- ArchiveService 최소 구현
- UI: 문서 목록, 편집, 저장, sync 라벨

## Sprint 03 권장 시작 순서
1. FTS5 `document_fts` 테이블 및 IndexingQueue debounce
2. SearchService 구현 + 검색 UI placeholder 연결
3. TrashService + 휴지통 이동/복구
4. File watcher 실제 구현 (외부 Markdown 변경 감지)
5. Document delete / move 경로
6. 폴더 트리 UI (LeftSidebar)

## 주의사항
- ArchiveService 경계 유지 — UI/MCP 직접 DB 접근 금지
- revision 검증 로직 유지
- sync_journal append-only 유지
- 개인 아카이브/외부 API/MCP 완성은 Sprint 5+

## macOS
- Sprint 3 전 `flutter build macos` smoke test 수행 권장

## 핵심 파일
- `lib/data/services/archive_service_impl.dart`
- `lib/data/sync/sync_service_impl.dart`
- `lib/application/sac_container.dart`
- `lib/ui/screens/main_shell.dart`
