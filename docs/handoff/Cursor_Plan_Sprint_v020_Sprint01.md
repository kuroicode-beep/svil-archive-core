# Cursor 작업 계획서 — SAC v0.2.0 Sprint 01

> **작업지시문**: [Dev_20260613_SAC_v0.2.0_Sprint01_Work_Instruction_v1_Lumi](https://app.notion.com/p/37d864048e5481edab77e22d45e7b405)
> **기준 HEAD**: `a9e0ee1`
> **브랜치**: `master`
> **작성**: Cursor, 2026-06-13

## 1. 현재 상태

| 항목 | 값 |
|------|-----|
| Repo | `C:\Projects\svil-archive-core` |
| Branch | `master` |
| HEAD | `a9e0ee1` — fix: refresh Windows autostart cmd when build path changes |
| Worktree | dirty — 기존 docs/asset/bin 변경·미추적 다수 존재 |

### dirty worktree 요약 (Sprint 01과 무관 — **건드리지 않음**)

- 수정: `.cursor/mcp.json`, 다수 `docs/handoff/`, `docs/reports/`
- 삭제: `docs/Idea_20260605_*` 3건
- 미추적: `asset/design/**`, `bin/**`, `docs/Dev_20260605_*`, `test_fixtures/` 등

**원칙**: Sprint 01 관련 파일만 수정. 기존 dirty 파일은 discard/overwrite/reformat 금지.

## 2. Codex 실사 반영 (partial_exists → 확장)

| 영역 | 판정 | Sprint 01 접근 |
|------|------|----------------|
| sync_journal | partial_exists | `action`에 relay event type 추가, `idempotency_key`/`payload_json` 컬럼 확장 |
| sensitivity/redaction | missing | `RelaySensitivityService` 신규 (regex 2차 필터, medium_unknown 기본) |
| public_lumi/Git exclude | partial_exists | `SAC_EXPORTS/public_lumi` 경로 + git commit safety 제외 + GC |
| capability token/rescue | partial_exists | relay 전용 hash 토큰 + result intake + manual rescue inbox |
| platform path/watcher | partial_exists | `PlatformPathAdapter` + `.crdownload`/`.tmp` 무시 + size stability |

## 3. 수정 예정 파일

| 파일 | 변경 |
|------|------|
| `app/flutter_app/lib/data/db/migrations.dart` | schema v12 |
| `app/flutter_app/lib/data/db/database_service_impl.dart` | busy_timeout, reset tables |
| `app/flutter_app/lib/data/sync/sync_journal_writer.dart` | relay append 확장 |
| `app/flutter_app/lib/data/platform/path_adapter.dart` | public_lumi export root |
| `app/flutter_app/lib/data/services/download_watcher_service_impl.dart` | watcher 안정화 |
| `app/flutter_app/lib/data/services/git_sync_service_impl.dart` | public_lumi/SAC_EXPORTS 제외 |
| `app/flutter_app/lib/application/sac_container.dart` | 서비스 조립·GC 시작 |

## 4. 신규 생성 예정 파일

| 파일 | 역할 |
|------|------|
| `lib/data/relay/relay_journal_events.dart` | relay event type 상수 |
| `lib/data/db/sqlite_write_guard.dart` | 단일 writer 직렬화 |
| `lib/data/platform/platform_path_adapter.dart` | 경로 정규화·임시파일 판별 |
| `lib/data/relay/relay_idempotency_service.dart` | idempotency key |
| `lib/data/relay/relay_sensitivity_service.dart` | sensitivity label + redaction |
| `lib/domain/models/relay_queue_item.dart` | relay_queue 모델 |
| `lib/domain/services/relay_queue_service.dart` | 인터페이스 |
| `lib/data/services/relay_queue_service_impl.dart` | SQLite 구현 |
| `lib/data/relay/relay_capability_token_service.dart` | hash 토큰 |
| `lib/data/relay/relay_result_intake_service.dart` | result 검증·manual rescue |
| `lib/data/relay/public_lumi_gc_service.dart` | 만료 capsule GC |
| `test/sprint_v020_sprint01_integration_test.dart` | Sprint 01 통합 테스트 |
| `docs/handoff/Cursor_Handoff_Sprint_v020_Sprint01.md` | 핸드오프 |
| `docs/handoff/Codex_Verification_Request_Sprint_v020_Sprint01.md` | Codex 검증 요청 |

## 5. 충돌 가능성

- `migrations.dart` / `sac_container.dart`: 최근 16H 스프린트와 동일 파일이나 relay 전용 영역만 추가
- `download_watcher_service_impl.dart`: 16 스프린트 로직 유지, 안정화만 보강
- dirty docs: **수정하지 않음**

## 6. 구현 순서

1. Migration v12 (relay_queue, relay_capability_tokens, relay_result_reviews, public_lumi_capsules, sync_journal 확장, relay_idempotency_keys)
2. SqliteWriteGuard + busy_timeout
3. RelayJournal 확장 (SyncJournalWriter + RelayIdempotencyService)
4. RelayQueueService (import_queue와 분리, journal 연동)
5. RelaySensitivityService (redaction)
6. PlatformPathAdapter + DownloadWatcher 보강
7. public_lumi export root + Git exclude
8. RelayCapabilityToken + RelayResultIntake + PublicLumiGc
9. sac_container 연동
10. 통합 테스트 + flutter analyze/test

## 7. 테스트 계획

| # | 검증 항목 |
|---|-----------|
| 1 | dirty worktree 무관 파일 미변경 |
| 2 | sync_journal 기존 append 유지 |
| 3 | relay event journal 기록 |
| 4 | import_queue ≠ relay_queue 상태 |
| 5 | idempotency 중복 방지 |
| 6 | `.crdownload`/`.tmp` 무시 |
| 7 | size stability 전 미처리 |
| 8 | medium_unknown → export 차단 |
| 9 | regex redaction preview |
| 10 | public_lumi git exclude |
| 11 | GC가 원본 문서 미삭제 |
| 12 | token 실패 → rejected/review |
| 13 | manual rescue journal 기록 |
| 14 | Windows 경로 정규화 |

## 8. Notion 완료보고서 기록 항목

- 시작/종료 HEAD, 브랜치
- dirty worktree 처리 방식
- 수정/신규 파일 목록
- migration v12 여부
- 구현/미구현 항목
- flutter analyze / test 결과
- Codex 검증 요청 포인트
