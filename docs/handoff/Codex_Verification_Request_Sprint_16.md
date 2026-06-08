# Codex Verification Request — Sprint 16 Git Sync + Download Watcher

> **기준 HEAD**: `5a2d99b` — **Codex PASS**
> **Sprint 15 PASS**: `d2021bd`
> **작업지시문**: [Sprint 16 WI](https://app.notion.com/p/379864048e54818798e3ddb6ecf55f3b)

## 재작업 (Sprint 16R) — PASS

- [x] **Blocker**: `commitPaths()`가 서비스 레벨에서 금지 경로 제외 (`isExcludedFromCommit`)
- [x] **Important**: `autoImport`는 **Experimental(비활성)** — `kDownloadAutoImportEnabled = false`, Settings 토글 비활성 + Coming Soon
- [x] **Advisory**: `database_service_impl.dart` `reset()`에 `import_queue` 포함 (`021cb44`)
- [x] 재작업 테스트 24/24

## 검증 체크리스트 — PASS

- [x] Git repo URL / sync interval 저장·로드
- [x] 다운로드 폴더 / prefix 목록 저장·로드
- [x] `ai_sync_chatgpt_` prefix가 import 후 파일명에서 제거
- [x] prefix 제거 후 파일명 중복 시 conflict 처리
- [x] 다운로드 폴더 `.md` 감지 + 하위 폴더 ON/OFF
- [x] Import Queue 등록 / 중복 재등록 방지
- [x] 수동 Import → Sprint 15 `executeApprovedImport(snapshot)` 흐름 유지
- [x] Import 후 SQLite documents 증가 + FTS 검색 (frontmatter 없이도)
- [x] 원본 다운로드 파일 유지
- [x] import report 생성
- [x] Git status 표시
- [x] Git commit 대상 제한 — `.sac/*.sqlite` 미포함 (서비스 레벨 강제)
- [x] `.gitignore` 필수 규칙 보강
- [x] Git push / pull `--ff-only`
- [x] 자동 import / 자동 push 기본 OFF (autoImport Experimental 비활성)
- [x] Local MCP 회귀 없음

## 명령

```bash
cd app/flutter_app && flutter analyze && flutter test test/sprint16_integration_test.dart
cd mcp/sidecar && npm ci && npm run build && npm test
```

## 소장님 Windows smoke (진행 가능)

- Settings > Git Sync 설정 저장/유지
- Downloads `ai_sync_chatgpt_*.md` → 스캔 → 큐 등록 → 수동 Import
- Import + Commit → `.md`/report만 → Push
- MCP `get_workspace_status` documentCount 확인

## Advisory

- `executeImport(dryRunOnly:false)` — UI/coordinator는 approved snapshot만. MCP/API import 개방 전 deprecated 권장.
- `npm ci --ignore-scripts`는 native binding 미빌드 → `npm ci`(scripts 포함) 권장.
