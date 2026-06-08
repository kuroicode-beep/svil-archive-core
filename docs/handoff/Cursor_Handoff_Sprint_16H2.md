# Cursor Handoff — Sprint 16H-2 Dry-run Input + Git Repo Save Fix

> **Sprint 16H 기준**: `412109b` (구현 `0976c1e`)
> **작업지시문**: [Sprint 16H-2 WI](https://app.notion.com/p/379864048e5481438e6bc11cc56be144)

## Sprint 16H-2 구현 요약 (Hotfix)

실사용을 막던 UI/설정 저장 2건을 수정했다.

| # | 문제 | 원인 | 수정 |
|---|------|------|------|
| 1 | 파일 Import dry-run 후 입력/토글 불가 | `_busy`가 dry-run 완료 후에도 파일 선택·옵션 토글까지 잠금 | `_dryRunInProgress` / `_executeInProgress` 분리 — dry-run 중·후에도 입력 유지 |
| 1b | (Codex blocker) 재 dry-run 실패 시 이전 snapshot 잔존 | catch 경로에서 snapshot 미무효화 | `_runDryRun()` 시작·catch 시 `_invalidateSnapshot()` |
| 2 | Settings GitHub repo URL 저장 안 됨 | Git 토글 저장 시 controller 값 미반영 → 빈 `repoUrl` persist + `_refresh`가 controller 덮어씀 | `_gitSyncFromControllers()` 병합 + FocusNode로 편집 중 덮어쓰기 방지 |

## Dry-run snapshot 정책

- dry-run 결과(미리보기 카드)는 **유지**
- 옵션/경로 변경 시 fingerprint 불일치 → **실행 버튼만 비활성**
- 변경 시 SnackBar: `이전 dry-run 결과가 무효화되었습니다. 다시 dry-run 해주세요.`
- 카드 라벨: `미리 검사 결과 (재검사 필요)` + 주황 안내 문구

## 주요 변경 파일

| 파일 | 내용 |
|------|------|
| `lib/ui/screens/file_import_screen.dart` | busy 분리, snapshot 유지·무효화 UX |
| `lib/ui/screens/settings_screen.dart` | Git repo URL controller 병합 저장, FocusNode, 저장 SnackBar |
| `lib/ui/screens/git_sync_screen.dart` | 저장된 repo URL / branch 표시 |
| `test/sprint16h2_integration_test.dart` | 8항목 (서비스 4 + 위젯 4) |

## 테스트

| 명령 | 결과 |
|------|------|
| `flutter analyze` | PASS |
| `flutter test test/sprint16h2_integration_test.dart` | **8/8** |
| `flutter test test/sprint16h_integration_test.dart` | **10/10** |
| `flutter test test/sprint16_integration_test.dart` | **24/24** |
| `mcp/sidecar npm test` | **10/10** |

## 소장님 smoke

1. 파일 Import — dry-run 후 파일/폴더 선택·토글 조작 가능
2. dry-run 후 옵션 변경 → 실행 버튼 비활성 + 재검사 안내
3. Settings — repo URL 입력 → **Git 설정 저장** 또는 토글 변경 → 재시작 후 유지
4. Git Sync 화면 — repo URL / branch 표시 일치

## Advisory

- dry-run **진행 중**에도 옵션 변경 가능 (race는 사용자 재 dry-run으로 해소)
- repo URL만 입력하고 아무 저장 동작 없이 화면 이탈 시 값 유실 (저장 버튼/토글 안내 문구 추가됨)
