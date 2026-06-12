# Cursor Handoff — SAC v0.2.0 Sprint 01 Foundation Hardening

> **작업지시문**: [Dev_20260613_SAC_v0.2.0_Sprint01_Work_Instruction_v1_Lumi](https://app.notion.com/p/37d864048e5481edab77e22d45e7b405)
> **작업 계획서**: `docs/handoff/Cursor_Plan_Sprint_v020_Sprint01.md`
> **Sprint 01 커밋**: `f6ea16e` (Codex 재검증 PASS_WITH_ADVISORY)
> **기준 HEAD**: `a9e0ee1`

## Sprint 01 구현 요약

Relay Layer 본구현 전 **기반 보강** 스프린트. 기존 `partial_exists` 영역을 확장·분리했다.

### 완료 항목

| 영역 | 구현 |
|------|------|
| sync_journal 확장 | relay event type `action` 기록, `idempotency_key`/`payload_json` 컬럼, `RelayJournalService` |
| relay_queue | schema v12 + `RelayQueueServiceImpl` (import_queue와 분리) |
| SQLite writer | `SqliteWriteGuard` + `PRAGMA busy_timeout=5000` |
| idempotency | `relay_idempotency_keys` + `RelayIdempotencyService` |
| sensitivity/redaction | `RelaySensitivityService` (medium_unknown 기본, regex 2차 필터) |
| public_lumi root | `resolvePublicLumiExportRoot` → `SAC_EXPORTS/public_lumi` |
| Git exclude | `isPublicLumiExportPath` → commit safety 제외 |
| public_lumi GC | `PublicLumiGcService` (만료 capsule 물리 삭제, journal 기록) |
| capability token | `RelayCapabilityTokenService` (hash only 저장) |
| result intake/rescue | `RelayResultIntakeService` + `relay_result_reviews` inbox |
| platform/watcher | `PlatformPathAdapter`, `.crdownload`/`.tmp` 무시, size stability |

### 미구현 (Sprint 02+)

- `RelayEventParser` 본구현
- `SAC_STATUS` export view
- Lumi Context Capsule UI
- 주기적 GC 타이머 (1시간) — 앱 시작 시 1회 GC만 연동
- settings/debug manual GC action UI

## dirty worktree 처리

- Sprint 01 범위 외 파일(docs/asset/bin/.cursor 등) **미수정**
- Sprint 01 관련 `app/flutter_app/**` + `docs/handoff/*v020*` 만 변경

## 테스트

- `flutter analyze`: No issues
- `sprint_v020_sprint01_integration_test`: **15/15** PASS (Codex 재작업: capability token target binding +4)
- `flutter test` 전체: 260 PASS / 12 FAIL (Windows temp dir lock·report consistency — Sprint 01 변경 무관 추정)
- `sprint16` + `16H` 회귀: **53/53** PASS

## Codex 검증 포인트

1. migration v12 적용 및 기존 DB 업그레이드
2. relay_queue ↔ import_queue 상태 분리
3. sync_journal relay event + idempotency
4. medium_unknown export 차단 + redaction
5. public_lumi Git exclude + GC 원본 미삭제
6. capability token hash 검증 + manual rescue journal
7. watcher `.crdownload`/size stability

## Sprint 02 진입 조건 (WI 기준)

- 상태 기록 가능 ✅
- 큐 분리 가능 ✅
- 민감정보 기본 보호 가능 ✅
- 임시 export 격리 가능 ✅
- 토큰 기반 결과 회수 준비 가능 ✅
- 플랫폼별 watcher 안정화 가능 ✅ (Windows first)
