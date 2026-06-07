---
title: "Rework Report — SAC Sprint 08"
author: "Cursor"
created: "2026-06-08"
sprint07_base_commit: "7d3b615"
codex_verification: "37886404-8e54-8179-bb46-cc3305cd0e1b"
rework_commit: "11b9454"
---

# 재작업 보고서 — SAC Sprint 08 Codex 검증 반영

## 01. 검증 결과 (Codex)
- **판정**: 부분완료 / 배포 가능 NO
- **BLOCKER**: B1 — `update_document`가 `baseRevision` 없이 실행 가능
- **IMPORTANT**: I1 — partial write rollback 부재
- **IMPORTANT**: I2 — Git 미커밋

## 02. 재작업 내용

### B1. baseRevision 필수 enforcement
- `queue_execution_service_impl.dart`
  - 실행 전 `update_document` / `update_metadata`에 `baseRevision` 없으면 `blocked`
  - `_dispatchApply()`에서 `?? sync.revision` 보정 제거

### I1. partial write rollback
- `archive_service_impl.dart`
  - `createDocument`: DB/sync 실패 시 생성된 Markdown 파일 삭제
  - `updateDocument`: 파일 write 후 DB/sync 실패 시 pre-write backup 복원

### I1/I2. 테스트 및 문서
- `test/sprint8_integration_test.dart` 3건 추가
  - approved update without baseRevision → blocked
  - create_document overwrite → failed
  - conflict 실행 후 원본 파일 유지

## 03. 테스트 결과
| 항목 | 결과 |
|------|------|
| `flutter analyze` | 통과 |
| `flutter test` | **80/80** passed |
| Sprint 8 tests | 24/24 |

## 04. 변경 파일
| 파일 | 변경 |
|------|------|
| `queue_execution_service_impl.dart` | baseRevision 필수 검증 |
| `archive_service_impl.dart` | create/update rollback |
| `test/sprint8_integration_test.dart` | Codex 권장 테스트 3건 |
| `docs/reports/Rework_Report_Sprint_08.md` | 본 문서 |
| `docs/handoff/Codex_Verification_Request_Sprint_08.md` | 재검증 항목 갱신 |

## 05. Git 커밋
- `11b9454` — Sprint 08 + Codex B1/I1 재작업
