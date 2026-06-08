# Cursor Handoff — Sprint 15 File Import Formal Registration

> **Sprint 14 기준**: `7d7fd5c` (Codex PASS)
> **작업지시문**: [Sprint 15 WI](https://app.notion.com/p/379864048e54816ab92dd88c8ad0d675)

## Sprint 15 구현 요약

- `DocumentImportService` — orphan 스캔, dry-run, 정식 등록, DB backup, import report
- `categoryPathFromRelativePath` — 커스텀 폴더 (`01_핵심규칙`, `03_프로젝트/SAC`) 지원
- `parseMarkdownForImport` — sac_id 없는 Markdown 허용
- UI: 사이드바 `파일 Import`, 무결성 화면 `Orphan Markdown 가져오기`
- 안전: dry-run 필수 UX, 원본 이동/삭제 없음, frontmatter 덮어쓰기 opt-in

## 주요 파일

| 경로 | 내용 |
|------|------|
| `lib/domain/models/document_import.dart` | Import 모델 |
| `lib/domain/services/document_import_service.dart` | 인터페이스 |
| `lib/data/services/document_import_service_impl.dart` | 구현 |
| `lib/data/import/markdown_import_parser.dart` | 느슨한 frontmatter 파싱 |
| `lib/ui/screens/file_import_screen.dart` | Import UI |
| `test/sprint15_integration_test.dart` | 10항목 |

## 소장님 smoke (SAC DOCS)

1. SAC 실행 → `SAC DOCS` workspace
2. **파일 Import** → **Workspace orphan 스캔**
3. dry-run → orphan ~216건 확인
4. **정식 등록 실행** (frontmatter 쓰기는 필요 시 ON)
5. 문서 아카이브 목록 / MCP `get_workspace_status` documentCount 확인

## 테스트

- `flutter analyze`: PASS
- `flutter test test/sprint15_integration_test.dart`: **10/10**
- full `flutter test`: report consistency 12건 실패 (미커밋 docs — Sprint 15 무관)
