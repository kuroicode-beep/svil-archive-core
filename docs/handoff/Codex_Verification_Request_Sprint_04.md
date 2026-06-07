# Codex Verification Request — Sprint 04

## 검증 대상
- Sprint 04 Document Archive UI (폴더 트리 / 메타데이터 / sync UI / Theme / File watcher)
- 기준 커밋: (Sprint 04 구현 커밋)
- 브랜치: `master`

## 검증 항목

### 기능
- [ ] 폴더 트리가 카테고리별로 문서를 표시하는가
- [ ] 문서 선택 시 편집기 + 우측 메타데이터 패널이 연동되는가
- [ ] 메타데이터 저장 시 SQLite `documents.project/tags/summary` 반영되는가
- [ ] sync 상태가 트리/편집기/푸터에 표시되는가
- [ ] 고대비 토글이 앱 전체 테마에 즉시 반영되고 재시작 후 유지되는가
- [ ] 파일 변경 시 `sync_state.status == dirty` 전이되는가

### 회귀
- [ ] Sprint 03 검색/휴지통/sync_state CASCADE 수정 회귀 없음
- [ ] path traversal 방어 유지

### 테스트
- [ ] `flutter analyze` 통과
- [ ] `flutter test` 18/18 통과
- [ ] `npm run build` (MCP sidecar) 통과

### Advisory
- macOS smoke test 미실행 (Windows)

## 핵심 파일
- `lib/ui/widgets/folder_tree_panel.dart`
- `lib/ui/widgets/right_context_panel.dart`
- `lib/ui/widgets/sync_status_badge.dart`
- `lib/data/services/theme_service_impl.dart`
- `lib/data/sync/workspace_file_watcher.dart`
- `lib/data/db/migrations.dart` (v3)
- `test/sprint4_integration_test.dart`
