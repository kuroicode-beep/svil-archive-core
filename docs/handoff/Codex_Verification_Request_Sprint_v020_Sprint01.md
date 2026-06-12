# Codex Verification Request — SAC v0.2.0 Sprint 01

> **작업지시문**: [Sprint 01 WI](https://app.notion.com/p/37d864048e5481edab77e22d45e7b405)
> **기준 HEAD**: `a9e0ee1` (구현 전) / 구현 후 커밋 TBD
> **핸드오프**: `docs/handoff/Cursor_Handoff_Sprint_v020_Sprint01.md`

## 검증 범위

Sprint 01 = Relay Foundation Hardening (Relay Layer 본구현 아님)

## 체크리스트

- [ ] dirty worktree 무관 파일 미변경 확인
- [ ] schema v12: relay_queue, relay_idempotency_keys, relay_capability_tokens, relay_result_reviews, public_lumi_capsules
- [ ] sync_journal idempotency_key/payload_json 확장
- [ ] import_queue vs relay_queue 상태 분리
- [ ] relay journal event 기록 (relay_task_created 등)
- [ ] idempotency 중복 방지
- [ ] SqliteWriteGuard + busy_timeout
- [ ] sensitivity medium_unknown + regex redaction
- [ ] public_lumi SAC_EXPORTS 경로 + git exclude
- [ ] public_lumi GC (원본 문서 미삭제)
- [ ] capability token hash 검증 + rejected/review inbox
- [ ] manual_rescue_approved journal
- [ ] platform path + watcher temp file ignore

## 테스트 명령

```bash
cd app/flutter_app
flutter analyze
flutter test test/sprint_v020_sprint01_integration_test.dart
flutter test
```

## 판정 형식

`Dev_20260613_SAC_v0.2.0_Sprint01_Codex_Verification_Report_v1`

PASS / PASS_WITH_ADVISORY / REWORK_REQUIRED / BLOCKED
