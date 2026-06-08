---
title: "Result Report — SAC Sprint 16"
author: "Cursor"
created: "2026-06-09"
sprint15_base_commit: "d2021bd"
---

# 완료 보고서 — SAC Sprint 16 Git Sync + Download Watcher

> **작업지시문**: [Dev_20260608_SAC_Work_Instruction_16_Git_Sync_Download_Watcher_v1_Lumi](https://app.notion.com/p/379864048e54818798e3ddb6ecf55f3b)

## 01. 작업 요약

- **목표**: 웹 AI 결과물(ai_sync_* Markdown)을 다운로드 폴더에서 회수하고 Git으로 동기화
- **결과**: ✅ 완료 (Codex 검증 대기)
- **Sprint 15 기준**: `d2021bd`

## 02. 구현 결과

✅ AI sync prefix 제거 (`ai_sync_chatgpt_` → 파일명만 제거) + source AI 매핑
✅ Import Queue (SQLite `import_queue`, migration v11)
✅ Download Watcher — 다운로드 폴더 `.md` 감지 (watcher + fallback scan, 하위폴더 옵션)
✅ Git Sync — status / pull(--ff-only) / commit(대상 제한) / push(force 금지) / .gitignore 보강
✅ 큐 Import — Sprint 15 `executeApprovedImport(snapshot)` 재사용 (우회 없음)
✅ Settings UI — Git Sync / 다운로드 감시 섹션 (안전 기본값 OFF)
✅ Git Sync 화면 — 상태/큐/작업(Import+Commit+Push, Pull+Import 등)
✅ 사이드바 `Git Sync / 다운로드` 진입점

## 03. 안전 기준 (작업지시문 §10)

| 항목 | 처리 |
|------|------|
| 원본 다운로드 파일 | 삭제하지 않음 (copy만) |
| SAC DOCS 자동 덮어쓰기 | 차단 (`conflictTargetPath`) |
| 토큰/비밀번호 | 저장·표시 없음 (OS git credential) |
| 자동 import / commit / push | 기본 OFF |
| commit 대상 | 지정 경로만 stage (`.sac/*.sqlite` 제외) |
| push | force 금지, pull `--ff-only` |

## 04. 변경 핵심 (버그 수정)

- `document_indexer.dart`: frontmatter 없는 문서(외부 import/orphan)가 이전엔 `parseMarkdownWithFrontmatter` 예외로 **silent skip**되어 검색 불가했음. fallback으로 원문 인덱싱하도록 수정. Sprint 16 다운로드 import(frontmatter OFF) 검색 가능의 전제.

## 05. 테스트

| 항목 | 결과 |
|------|------|
| `flutter analyze` | PASS |
| `flutter test sprint16` | 18/18 |
| `mcp/sidecar` build + test | 10/10 (native 2/2) |
| full `flutter test` | sprint16 전부 통과 / 기존 report-consistency 12건 실패(미커밋 docs, Sprint 16 무관) |

## 06. 주요 파일

- `lib/data/import/ai_sync_prefix.dart`
- `lib/domain/models/import_queue_item.dart`, `git_sync.dart`
- `lib/domain/services/import_queue_service.dart`, `git_sync_service.dart`, `download_watcher_service.dart`
- `lib/data/services/import_queue_service_impl.dart`, `git_sync_service_impl.dart`, `download_watcher_service_impl.dart`, `download_import_coordinator.dart`
- `lib/ui/screens/git_sync_screen.dart`
- `lib/data/db/migrations.dart` (v11), `document_indexer.dart`, `document_import*.dart`, `settings*.dart`, `sac_container.dart`, `main_shell.dart`, `left_sidebar.dart`, `settings_screen.dart`
- `test/sprint16_integration_test.dart`

## 07. 소장님 smoke (작업지시문 §12)

- [ ] Git 설정 저장/유지
- [ ] 다운로드 `ai_sync_chatgpt_*.md` 감지 → `*.md` 등록 예정명
- [ ] Import → 앱 표시 + 원본 유지
- [ ] Import + Commit → `.md`/report만 commit → Push → remote 반영
- [ ] MCP `get_workspace_status` documentCount 유지/증가

## 08. Advisory

- `executeImport(dryRunOnly:false)` 미사용(UI/coordinator는 approved snapshot만). MCP/API import 개방 전 deprecated 권장.
- 작업지시문의 `npm ci --ignore-scripts`는 native binding 미빌드로 native 테스트 실패 → `npm ci`(scripts 포함) 사용 권장.

## 09. Git 커밋

- 구현 커밋: (push 후 기록)
- Codex 검증: 대기
