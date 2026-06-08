# Codex Verification Request — Sprint 15 File Import

> **기준 HEAD**: `d2021bd` — **Codex PASS**
> **Sprint 14 PASS**: `7d7fd5c`
> **작업지시문**: [Sprint 15 WI](https://app.notion.com/p/379864048e54816ab92dd88c8ad0d675)

## 재작업 (Codex blocker 대응) — PASS

- [x] dry-run snapshot 고정 — 옵션/경로 변경 시 execute 차단
- [x] `executeApprovedImport` — 확인한 후보만 등록 (재스캔 없음)
- [x] 외부 copy → `documents/Import/<name>` 기존 파일 시 `conflictTargetPath`
- [x] 동일 스캔 배치 sac_id / content hash 중복 감지
- [x] 테스트 16/16 (snapshot, target conflict, sac_id, hash, frontmatter OFF, bulk count)

## 검증 체크리스트 — PASS

- [x] `DocumentImportService` dry-run / execute
- [x] 커스텀 폴더 category (`01_핵심규칙`, `03_프로젝트/SAC`)
- [x] sac_id 없는 Markdown 등록
- [x] skip registered / subfolder 옵션
- [x] DB backup + import report (`.sac/backups`, `.sac/imports`)
- [x] FTS 인덱싱 + search 반영
- [x] 원본 Markdown 삭제/이동 없음
- [x] frontmatter opt-in (자동 덮어쓰기 금지)
- [x] integrity orphan 감소
- [x] Sprint 14 MCP archive 회귀 없음

## Advisory

- `executeImport(dryRunOnly:false)` — UI 밖 호출 시 approved snapshot 우회 가능. MCP/API import 개방 전 deprecated 또는 internal-only 권장.

## 명령

```bash
cd app/flutter_app && flutter analyze && flutter test test/sprint15_integration_test.dart
cd mcp/sidecar && npm ci && npm run build && npm test
```

## 소장님 Windows smoke (진행 가능)

- Import → workspace `documents/` → dry-run → execute → UI + MCP documentCount (~216건)
