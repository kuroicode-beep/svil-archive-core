---
title: "Result Report — SAC Sprint 15"
author: "Cursor"
created: "2026-06-08"
sprint14_base_commit: "7d7fd5c"
---

# 완료 보고서 — SAC Sprint 15 File Import Formal Registration

> **작업지시문**: [Dev_20260608_SAC_Work_Instruction_15_File_Import_Formal_Registration_v1_Lumi](https://app.notion.com/p/379864048e54816ab92dd88c8ad0d675)

## 01. 작업 요약

- **목표**: 탐색기로 복사한 orphan Markdown을 SAC에 정식 등록 (SQLite + FTS + MCP 반영)
- **결과**: ✅ **Codex PASS** (`d2021bd`) — SAC DOCS 216건 import smoke 진행 가능
- **Sprint 14 기준**: `7d7fd5c`

## 02. 구현 결과

✅ `DocumentImportService` — scan / dry-run / execute / backup / report  
✅ 커스텀 폴더 category path 지원  
✅ sac_id 없는 Markdown import + opt-in frontmatter 보강  
✅ UI `파일 Import` + 무결성 `Orphan Markdown 가져오기`  
✅ `sprint15_integration_test.dart` 16/16  
✅ **재작업 (Codex blocker)** — dry-run snapshot 고정 + execute fingerprint 검증  
✅ **재작업** — 외부 copy target 충돌 시 `conflictTargetPath` + 덮어쓰기 차단  
✅ **재작업** — 동일 스캔 배치 내 sac_id / content hash 중복 감지  

## 03. Codex blocker 재작업

| Blocker | 조치 |
|---------|------|
| dry-run vs execute 불일치 | `ImportApprovedSnapshot` + 옵션/경로 변경 시 snapshot 무효화, `executeApprovedImport`만 실행 |
| 외부 파일이 workspace orphan 덮어쓰기 | `documents/Import/<name>` 존재 시 dry-run `conflictTargetPath`, register 시 copy 거부 |

## 04. 테스트

| 항목 | 결과 |
|------|------|
| `flutter analyze` | PASS |
| `flutter test sprint15` | 16/16 |
| full `flutter test` | 189 pass / 12 fail (report consistency — 미커밋 docs) |

## 05. Codex 재검증 (PASS)

| 항목 | 결과 |
|------|------|
| HEAD / origin | `d2021bd` |
| `flutter analyze` | PASS |
| `flutter test sprint15` | 16/16 |
| `mcp/sidecar` build + test | 10/10 |
| Blocker 1 dry-run/execute | 닫힘 |
| Blocker 2 overwrite | 닫힘 |
| Sprint 14 MCP 회귀 | 없음 |

**Advisory**: `executeImport(dryRunOnly:false)`가 서비스 API에 남아 UI 밖 호출자가 snapshot 흐름을 우회할 수 있음. MCP/API import 개방 전 deprecated 또는 internal-only 권장.

## 06. 소장님 smoke

- [ ] SAC DOCS workspace orphan import (~216건)
- [ ] MCP `documentCount > 0` after import

## 07. Git 커밋

- 초기 Sprint 15: `7c519e0`
- 재작업 (Codex PASS): `d2021bd`
- Codex 검증: **PASS**
