# Cursor Handoff — Sprint 16H-3 Archive / Import Blocker UI Fix

> **Sprint 16H-3 커밋**: `582355a` / Sprint 16H-2 `1b5080d`
> **작업지시문**: [Sprint 16H-3 WI](https://app.notion.com/p/37a864048e548173871cd7da89cc75e4)

## Sprint 16H-3 구현 요약 (Hotfix)

| # | 문제 | 원인 | 수정 |
|---|------|------|------|
| 1 | Import dry-run 후 결과/이유 미표시 | 결과 카드가 화면 하단 + dry-run 전 안내 없음 | 상단 요약 카드, 상태별 안내, 자동 스크롤, 경로 검증 |
| 2 | 문서 아카이브 중앙 회색 빈 패널 | `documents/Import` 등 커스텀 category가 `categoryFromRelativePath`에서 예외 → 목록 미렌더 | `folderCategoryFromRelativePath` + `ArchiveListPanel` (loading/empty/error/ready) |

## 주요 변경 파일

| 파일 | 내용 |
|------|------|
| `lib/data/platform/path_adapter.dart` | `folderCategoryFromRelativePath()` |
| `lib/ui/widgets/archive_list_panel.dart` | 신규 — 아카이브 목록 상태 UI |
| `lib/ui/widgets/folder_tree_panel.dart` | Import category 표시 + empty 안내 |
| `lib/ui/screens/main_shell.dart` | ArchiveListPanel 연동, load error 상태, refresh |
| `lib/ui/screens/file_import_screen.dart` | dry-run 요약/안내/스크롤/경로 검증 |
| `lib/ui/screens/document_editor_panel.dart` | empty 상태 테마 대응 |
| `test/sprint16h3_integration_test.dart` | 11항목 |

## 테스트

| 명령 | 결과 |
|------|------|
| `flutter analyze` | PASS |
| `sprint16h3_integration_test` | **11/11** |
| `sprint16h2_integration_test` | **8/8** |
| `sprint16h_integration_test` | **10/10** |
| `sprint16_integration_test` | **24/24** |
| `mcp/sidecar npm test` | **10/10** |

## 소장님 smoke

1. 파일 Import — `C:\Projects\노션 백업` 등 한글 경로 폴더 선택 → dry-run → 상단 요약 + 상세 결과 확인
2. 등록 가능 N건이면 **정식 등록 실행** 활성화
3. 0건이면 이유 문구( Markdown 없음 / 이미 등록 등) 확인
4. Import 후 **문서 아카이브** — 목록에 `Import` category 문서 표시
5. 고대비 ON — 목록 텍스트 가독성 확인

## Advisory

- dry-run 후 자동 스크롤은 결과 영역 기준 — 매우 긴 후보 목록은 수동 스크롤 필요
- sidecar `npm test` 전 `npm ci && npm rebuild better-sqlite3` 필요할 수 있음 (Node ABI)
