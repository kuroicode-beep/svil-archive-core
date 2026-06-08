# Cursor Handoff — Sprint 16 Git Sync + Download Watcher

> **Sprint 15 PASS**: `d2021bd` (Codex PASS)
> **작업지시문**: [Sprint 16 WI](https://app.notion.com/p/379864048e54818798e3ddb6ecf55f3b)

## Sprint 16 구현 요약

웹 AI(ChatGPT 등) 결과물을 다운로드 폴더에서 회수하고 Git으로 동기화하는 기능.
Remote MCP 대신 Git Sync + Download Watcher + Import Queue로 현실적 연결을 지원한다.

- **AI sync prefix 제거**: `ai_sync_chatgpt_` 등 prefix를 파일명에서만 제거 (`ai_sync_prefix.dart`)
- **Import Queue**: 감지 파일을 SQLite `import_queue`에 등록 (migration v11)
- **Download Watcher**: 다운로드 폴더 `.md` 감지 → 큐 등록 (watcher + fallback scan)
- **Git Sync**: status / pull(--ff-only) / commit(대상 제한) / push(force 금지) / .gitignore 보강
- **import 흐름**: Sprint 15 `executeApprovedImport(snapshot)` 재사용 (우회 없음)
- **안전 기본값**: 자동 import / 자동 commit / 자동 push / 다운로드 감시 모두 OFF

## 주요 파일

| 경로 | 내용 |
|------|------|
| `lib/data/import/ai_sync_prefix.dart` | prefix 감지/제거 + source AI 매핑 |
| `lib/domain/models/import_queue_item.dart` | Import Queue 모델 |
| `lib/domain/services/import_queue_service.dart` + `lib/data/services/import_queue_service_impl.dart` | 큐 CRUD |
| `lib/domain/models/git_sync.dart` | Git 상태/결과 모델 |
| `lib/domain/services/git_sync_service.dart` + `lib/data/services/git_sync_service_impl.dart` | git CLI 래퍼 |
| `lib/domain/services/download_watcher_service.dart` + `lib/data/services/download_watcher_service_impl.dart` | 다운로드 감시 |
| `lib/data/services/download_import_coordinator.dart` | 큐 → approved snapshot import |
| `lib/domain/models/settings.dart` | `GitSyncSettings`, `DownloadWatcherSettings` |
| `lib/ui/screens/git_sync_screen.dart` | Git Sync / 큐 UI |
| `lib/data/db/migrations.dart` | `import_queue` v11 |
| `test/sprint16_integration_test.dart` | 18 항목 |

## 변경된 기존 파일

- `document_indexer.dart` — **버그 수정**: frontmatter 없는 문서(외부 import/orphan)도 인덱싱되도록 fallback 추가 (이전에는 `parseMarkdownWithFrontmatter` 예외로 silent skip되어 검색 불가)
- `document_import.dart` / `document_import_service_impl.dart` — `targetFileNameOverrides` (prefix 제거 파일명 import)
- `settings_service_impl.dart` — git/다운로드 설정 키
- `sac_container.dart`, `main_shell.dart`, `left_sidebar.dart`, `settings_screen.dart` — 서비스 wiring + UI

## 소장님 smoke (작업지시문 §12)

1. Settings > Git Sync: repo URL / branch / interval 입력 → 재시작 후 유지
2. Downloads에 `ai_sync_chatgpt_20260608_test.md` → Git Sync 화면 "다운로드 스캔" → 등록 예정 `20260608_test.md`
3. 큐 항목 Import → 앱에 `20260608_test.md` 표시, 원본 유지
4. Import + Commit → commit 대상에 `.md`/report만 포함 → Push → remote 반영
5. Cursor MCP `get_workspace_status` documentCount 유지/증가

## 재작업 (Codex blocker, `17dea85` 이후)

- **Blocker**: `git_sync_service_impl.dart`에 `isExcludedFromCommit()` 추가. `commitPaths()`가 `.sqlite`/`*.zip`/`bin/windows/`/`.env`/`secrets.*`/`.sac` cache·logs·backups를 stage에서 제거 (서비스 레벨 최종 방어선).
- **Important**: `download_watcher_service_impl.dart`에 coordinator 주입. `autoImport` ON 시 `scanOnce`가 dry-run 후 안전 후보만 `executeApprovedImport`로 자동 등록 (conflict 자동 중단).
- **Advisory**: `database_service_impl.dart` `reset()`에 `import_queue` 포함.

## 테스트

- `flutter analyze`: PASS
- `flutter test test/sprint16_integration_test.dart`: **23/23** (재작업 5건 추가)
- `mcp/sidecar` `npm ci && npm run build && npm test`: **10/10** (native 2/2)
- full `flutter test`: sprint16 전부 통과. 기존 report-consistency 12건 실패는 미커밋 docs 의존 (Sprint 16 무관, Sprint 15 핸드오프에 기록됨)

## Advisory

- `executeImport(dryRunOnly:false)`는 여전히 서비스 API에 존재. UI/coordinator는 `executeApprovedImport`만 사용. MCP/API import 개방 전 deprecated 권장 (Sprint 15 advisory 유지).
- Git 인증은 OS git credential 사용. 토큰/비밀번호는 저장/표시하지 않음.
