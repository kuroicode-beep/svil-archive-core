# Rework Report — SAC v0.2.0 Sprint 01 (Codex REWORK_REQUIRED)

> **원본 검증**: `docs/reports/Dev_20260613_SAC_v0.2.0_Sprint01_Codex_Verification_Report_v1.md`
> **작업지시문**: [Sprint 01 WI](https://app.notion.com/p/37d864048e5481edab77e22d45e7b405)
> **재작업**: Cursor, 2026-06-13

## 1. Codex 이슈

**Critical**: `RelayCapabilityTokenService.validate()` — 토큰에 `target_document_id` / `target_path`가 저장되어 있어도 relay result가 target을 누락하면 통과할 수 있었음.

## 2. 수정 내용

`app/flutter_app/lib/data/relay/relay_capability_token_service.dart`

- 저장된 `target_document_id`가 있으면 result도 **반드시 제공**하고 일치해야 함 (누락 시 거부)
- 저장된 `target_path`가 있으면 result도 **반드시 제공**하고 정규화 후 일치해야 함
- `allowed_target`은 result의 `target_document_id` 또는 `target_path` 중 하나와 일치해야 함 (누락 시 거부)
- path 비교: `normalizePlatformPath` + slash/case 정규화

## 3. 테스트 추가

`test/sprint_v020_sprint01_integration_test.dart` — 4건 추가

- missing `target_document_id` → rejected (+ intake review)
- wrong `target_document_id` → rejected
- matching `target_document_id` → accepted (+ intake success)
- missing/wrong/matching `target_path` → rejected/rejected/accepted

## 4. 검증 결과

| 명령 | 결과 |
|------|------|
| `flutter analyze` | No issues |
| `flutter test test/sprint_v020_sprint01_integration_test.dart` | **15/15** PASS |
| `flutter test test/sprint16_integration_test.dart test/sprint16h_integration_test.dart` | **34/34** PASS |

## 5. Codex 재검증 요청

Sprint 01 capability token target binding 회귀 테스트 포함 재검증 요청.
