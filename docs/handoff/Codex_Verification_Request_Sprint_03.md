# Codex 검증 요청 — SAC Sprint 03

## 검증 대상
- 작업지시문: `Dev_20260606_SAC_Work_Instruction_03_Search_Indexing_Trash_v1_Lumi`
- 완료보고서: `docs/reports/Result_Report_Sprint_03.md`
- 기준 커밋: Sprint 02 최종 `be817b7` 위 Sprint 03 구현

## 검증 포인트
1. FTS5 검색 동작 및 삭제 문서 제외
2. document_chunks / document_fts schema 및 migration v2
3. IndexingQueue debounce/batch
4. 문서 수정 후 검색 인덱스 갱신
5. Trash 이동/복구/완전삭제 + path containment
6. path traversal 회귀 테스트
7. relativeDir/type 정책 일관성
8. flutter analyze/test 통과

## 회귀 테스트
- `test/sprint3_integration_test.dart`
- `test/path_adapter_test.dart`
- `test/archive_integration_test.dart`
