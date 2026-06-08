# Cursor Handoff — Sprint 16H Emergency UI / Settings / Ollama Model Fix

> **Sprint 16R PASS**: `5a2d99b` / docs `ba54a05`
> **작업지시문**: [Sprint 16H WI](https://app.notion.com/p/379864048e54819ab883fd92ac0305dd)

## Sprint 16H 구현 요약 (Hotfix)

실사용 중 막히던 설정/UX 3건을 수정했다.

| # | 문제 | 수정 |
|---|------|------|
| 1 | 다운로드 감시 폴더 변경 UI 없음 | Settings + Git Sync 화면에 **감시 폴더 변경** / **기본 폴더 복원** 버튼 |
| 2 | ON/OFF 스위치 클릭 시 화면 상단 이동 | Settings `_refresh()`가 토글 저장 시 전체 로딩 스피너 생략 + `ScrollController`/`PageStorageKey` |
| 3 | Ollama 모델 선택 불가 | `ollamaModel` 설정 저장 + 모델 목록 새로고침 + dropdown + 미존재 모델 경고 |

## 주요 변경 파일

| 파일 | 내용 |
|------|------|
| `lib/domain/models/settings.dart` | `AppSettings.ollamaModel` |
| `lib/data/services/settings_service_impl.dart` | `ollama_model` 키 persist |
| `lib/ui/screens/settings_screen.dart` | 폴더 변경 UI, scroll fix, Ollama model UI |
| `lib/ui/screens/git_sync_screen.dart` | 다운로드 감시 폴더 카드 + 변경/복원 |
| `lib/ui/screens/main_shell.dart` | `onDownloadsChanged` wiring |
| `lib/application/sac_container.dart` | 폴더 변경 시 watcher stop+start |
| `lib/data/services/download_watcher_service_impl.dart` | `resolveDefaultDownloadsFolder()` |
| `test/sprint16h_integration_test.dart` | 10항목 |

## 안전

- 폴더 변경 시 기존 Import Queue 삭제 없음
- watcher만 재시작 (`applyDownloadWatcherSettings`)
- Ollama 연결 실패 시 앱 전체 오류 없음 (빈 목록 + 안내)
- Sprint 16/16R Git Sync·Download Watcher 로직 회귀 없음

## 테스트

- `flutter analyze`: PASS
- `flutter test test/sprint16h_integration_test.dart`: **10/10**
- `flutter test test/sprint16_integration_test.dart`: **24/24** (회귀)
- `mcp/sidecar` build + test: (push 후 기록)

## 소장님 smoke

1. Settings > 다운로드 감시 — **감시 폴더 변경** → 저장 → 재시작 후 유지
2. Git Sync 화면 — 폴더 경로 표시 + 변경 버튼
3. Settings — 다운로드/Git/Startup 토글 후 **스크롤 위치 유지** 확인
4. Ollama 실행 → Settings > Local AI — **모델 목록 새로고침** → 모델 선택 → 저장

## Advisory

- 스크롤 위치 widget test는 headless tray/sidecar 환경에서 hang → integration + 수동 smoke 권장
- `DropdownButtonFormField.initialValue`는 선택 변경 후 즉시 반영이 제한될 수 있음 — 저장 후 `_refresh`로 동기화
