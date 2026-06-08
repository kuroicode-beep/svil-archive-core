# Codex Verification Request — Sprint 16 Git Sync + Download Watcher

> **기준 HEAD**: 재작업 commit (push 후 기록) / 초기 `17dea85`
> **Sprint 15 PASS**: `d2021bd`
> **작업지시문**: [Sprint 16 WI](https://app.notion.com/p/379864048e54818798e3ddb6ecf55f3b)

## 재작업 (Codex blocker 대응 — Sprint 16R)

- [ ] **Blocker**: `commitPaths()`가 서비스 레벨에서 금지 경로 제외 (`isExcludedFromCommit`) — `.sqlite`/`*.zip`/`bin/windows/`/`.env`/`secrets.*`/`.sac` cache·logs·backups. 제외 path를 결과(stderr)에 포함, 전부 제외 시 add/commit 미실행 + 에러
- [ ] **Important**: `autoImport`는 이번 스프린트 **Experimental(비활성)** — `kDownloadAutoImportEnabled = false`, Settings 토글 비활성 + Coming Soon. 설정 ON이어도 자동 import 미수행(큐 등록만)
- [ ] **Advisory**: `database_service_impl.dart` `reset()`에 `import_queue` 추가 커밋 포함 (`021cb44`)
- [ ] 재작업 테스트 24/24 (commit 제외 3건, autoImport 비활성 검증 등)

## 검증 체크리스트 (작업지시문 §11, §15)

- [ ] Git repo URL / sync interval 저장·로드
- [ ] 다운로드 폴더 / prefix 목록 저장·로드
- [ ] `ai_sync_chatgpt_` prefix가 import 후 파일명에서 제거 (`20260608_*.md`)
- [ ] prefix 제거 후 파일명 중복 시 conflict 처리 (자동 덮어쓰기 차단)
- [ ] 다운로드 폴더 `.md` 감지 + 하위 폴더 ON/OFF
- [ ] Import Queue 등록 / 중복 재등록 방지
- [ ] 수동 Import → Sprint 15 `executeApprovedImport(snapshot)` 흐름 유지 (우회 없음)
- [ ] Import 후 SQLite documents 증가 + FTS 검색 가능 (frontmatter 없이도)
- [ ] 원본 다운로드 파일 유지 (삭제 금지)
- [ ] import report 생성 (`.sac/imports`)
- [ ] Git status (branch/head/dirty) 표시
- [ ] Git commit 대상 제한 — `.sac/*.sqlite` 미포함
- [ ] `.gitignore` 필수 규칙 보강
- [ ] Git push 수동 실행 / pull `--ff-only`
- [ ] 자동 import / 자동 push 기본 OFF
- [ ] Local MCP 회귀 없음

## 명령

```bash
cd app/flutter_app && flutter analyze && flutter test test/sprint16_integration_test.dart
cd mcp/sidecar && npm ci && npm run build && npm test
```

> 참고: 작업지시문은 `npm ci --ignore-scripts`를 명시하나, `--ignore-scripts`는 better-sqlite3 native binding을 빌드하지 않아 `native_binding.test.ts`가 실패한다. native 검증을 위해 `npm ci`(scripts 포함)를 사용해야 한다. (advisory)

## 결과 (Cursor 자체 확인)

- `flutter analyze`: PASS
- `flutter test test/sprint16_integration_test.dart`: 18/18
- `mcp/sidecar`: build OK, `npm test` 10/10 (native 2/2)
- full `flutter test`: sprint16 전부 통과. 기존 report-consistency 12건 실패는 미커밋 docs 의존(Sprint 16 무관).

## 변경 핵심 / 주의

- `document_indexer.dart`에서 frontmatter 없는 문서도 인덱싱되도록 fallback 추가 (이전 silent skip 버그 수정). Sprint 15 import(frontmatter ON) 회귀 없음 확인.
- Git 인증은 OS git credential 사용. 토큰/비밀번호 평문 저장·표시 없음.

## Advisory

- `executeImport(dryRunOnly:false)`는 UI/coordinator에서 미사용. MCP/API import 개방 전 deprecated 권장.
