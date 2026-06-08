# Cursor Handoff — Sprint 12 RC Build Approval

> **Sprint 11 기준**: `5e02b31`
> **Sprint 12 구현 커밋**: `2e2e4da`
> **작업지시문**: Notion 차단 — 채팅 WI (2026.06.08, 루미)

## Sprint 12 구현 요약

- migration v10 — `rc_build_artifacts`, `release_approval_records`, `rc_tag_readiness_checks`
- `RcBuildArtifactService` — artifact 기록 + path masking
- `SmokeApprovalService` — Windows/macOS smoke approval
- `ReleaseApprovalService` — draft/waiting_smoke/ready_for_approval/approved/rejected/blocked
- `RcTagReadinessService` — v0.1.0-rc.1 readiness checks
- `FinalReleaseBundleExportService` — `sac_v0.1_rc_bundle_*.md`
- Dashboard RC Final Status / Settings Release 최종 보강

## Codex에게

- `docs/handoff/Codex_Verification_Request_Sprint_12.md` 기준 검증
- smoke pending → ready 과장 여부
- final bundle 민감정보 미포함
- Git tag 자동 생성 없음

## 소장님에게

- Integrity에서 macOS/Windows smoke PASS 기록
- Settings > Release에서 final bundle export 확인
- `v0.1.0-rc.1` tag는 별도 승인 후 수동 생성
