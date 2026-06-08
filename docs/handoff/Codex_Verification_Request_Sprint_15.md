# Codex Verification Request — Sprint 15 File Import

> **기준 HEAD**: `(after Sprint 15 commit)`
> **Sprint 14 PASS**: `7d7fd5c`
> **작업지시문**: [Sprint 15 WI](https://app.notion.com/p/379864048e54816ab92dd88c8ad0d675)

## 재작업 (Codex blocker 대응)

- [ ] dry-run snapshot 고정 — 옵션/경로 변경 시 execute 차단
- [ ] `executeApprovedImport` — 확인한 후보만 등록 (재스캔 없음)
- [ ] 외부 copy → `documents/Import/<name>` 기존 파일 시 `conflictTargetPath`
- [ ] 동일 스캔 배치 sac_id / content hash 중복 감지
- [ ] 테스트 16/16 (snapshot, target conflict, sac_id, hash, frontmatter OFF, bulk count)

## 검증 체크리스트

- [ ] `DocumentImportService` dry-run / execute
- [ ] 커스텀 폴더 category (`01_핵심규칙`, `03_프로젝트/SAC`)
- [ ] sac_id 없는 Markdown 등록
- [ ] skip registered / subfolder 옵션
- [ ] DB backup + import report (`.sac/backups`, `.sac/imports`)
- [ ] FTS 인덱싱 + search 반영
- [ ] 원본 Markdown 삭제/이동 없음
- [ ] frontmatter opt-in (자동 덮어쓰기 금지)
- [ ] integrity orphan 감소
- [ ] Sprint 14 MCP archive 회귀 없음

## 명령

```bash
cd app/flutter_app && flutter analyze && flutter test test/sprint15_integration_test.dart
cd mcp/sidecar && npm ci && npm run build && npm test
```

## 소장님 Windows smoke

- Import → workspace `documents/` → dry-run → execute → UI + MCP documentCount
