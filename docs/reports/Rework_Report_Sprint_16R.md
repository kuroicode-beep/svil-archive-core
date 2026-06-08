---
title: "Rework Report — SAC Sprint 16R"
author: "Cursor"
created: "2026-06-09"
sprint16_base_commit: "17dea85"
---

# 재작업 보고서 — SAC Sprint 16R (Git Sync / Download Watcher)

> **작업지시문**: [Sprint 16 WI](https://app.notion.com/p/379864048e54818798e3ddb6ecf55f3b)
> **Codex 검증 기준**: `17dea85` (PASS 보류)

## 01. 재작업 요약

- **목표**: Codex PASS 보류 blocker/important/advisory 해소
- **결과**: ✅ **Codex PASS** (`5a2d99b`)

## 02. 조치 내역

### Blocker — commit 제외 서비스 레벨 강제
- `git_sync_service_impl.dart`에 `isExcludedFromCommit(relativePath)` 추가
- `commitPaths()`가 금지 경로를 stage 전에 제거
  - SAC 내부 DB: `*.sqlite` / `*.sqlite-wal` / `*.sqlite-shm`
  - `.sac/cache/`, `.sac/tmp/`, `.sac/logs/`, `.sac/backups/`
  - 배포 산출물: `bin/windows/`, `*.zip`
  - 환경/비밀: `.env`, `.env.*`, `secrets.*`
- 제외된 path 목록을 결과 `stderr`에 포함
- 모든 path가 제외되면 `git add`/`commit`을 실행하지 않고 `success=false` + 명확한 에러 반환
- 허용 유지: import된 `documents/**/*.md`, import report(`.sac/imports/*.md`)

### Important — autoImport Experimental(비활성) 확정
- 소장님 결정에 따라 이번 스프린트에서는 autoImport를 **명확히 비활성화**
- `download_watcher_service_impl.dart`: `const kDownloadAutoImportEnabled = false` 하드 플래그
  - `scanOnce`의 자동 import 경로를 플래그로 차단 → 설정 ON이어도 큐 등록만 수행
  - coordinator 경로는 향후 활성화를 위해 플래그 뒤에 보존
- `settings_screen.dart`: 자동 import 토글 비활성화(`onChanged: null`, `value: false`) + "Coming Soon" 안내

### Advisory — DB reset 변경 포함
- `database_service_impl.dart` `reset()`에 `import_queue` 포함 (커밋 `021cb44`에 반영됨)

## 03. 테스트

| 항목 | 결과 |
|------|------|
| `flutter analyze` | PASS |
| `flutter test test/sprint16_integration_test.dart` | 24/24 |
| `mcp/sidecar` `npm ci && npm run build && npm test` | 10/10 (native 2/2) |
| full `flutter test` | sprint16 전부 통과 / 기존 report-consistency 12건 실패(미커밋 docs, Sprint 16 무관) |

추가/갱신 테스트:
- `isExcludedFromCommit` 범주 차단 단위 테스트
- `commitPaths` 금지 경로 제외(서비스 레벨) — 안전 md만 commit
- `commitPaths` 전부 제외 시 실패
- autoImport 비활성 플래그(`kDownloadAutoImportEnabled == false`)
- autoImport ON이어도 큐 등록만(자동 import 미수행)

## 04. 변경 파일

| 파일 | 변경 |
|------|------|
| `lib/data/services/git_sync_service_impl.dart` | `isExcludedFromCommit` + `commitPaths` 필터 |
| `lib/data/services/download_watcher_service_impl.dart` | `kDownloadAutoImportEnabled` 플래그로 자동 import 비활성 |
| `lib/ui/screens/settings_screen.dart` | autoImport 토글 비활성 + Coming Soon |
| `lib/data/db/database_service_impl.dart` | `reset()` `import_queue` (021cb44) |
| `test/sprint16_integration_test.dart` | 재작업 검증 테스트 |
| `docs/reports/Result_Report_Sprint_16.md`, `docs/handoff/*_Sprint_16.md` | 재작업 반영 |

## 05. Git 커밋

- 초기 구현: `17dea85`
- 재작업 1차: `021cb44`
- Sprint 16R: `5a2d99b`
- Codex 검증: **PASS**

## 06. 핸드오프

- **Codex에게**: HEAD(아래 커밋) 기준 재검증 요청. autoImport는 의도적으로 Experimental(비활성) — 설정 ON이어도 자동 import 미수행이 정상.
- **주의**: 작업지시문 §11 명령의 `npm ci --ignore-scripts`는 native binding 미빌드로 native 테스트 실패 → `npm ci`(scripts 포함) 사용 권장.
