# Codex Verification Request — Sprint 08 (재검증)

> **Sprint 07 기준 커밋**: `7d3b615`
> **Sprint 08 구현 커밋**: `548236f`
> **Codex 1차 검증**: 부분완료 — B1 + I1 + I2
> **재작업 보고서**: `docs/reports/Rework_Report_Sprint_08.md`
> **범위**: Queue Execution / Safe Apply

## 검증 항목

- [x] migration v6 — execution/dry-run tables + work_queue 컬럼
- [x] approved ticket만 dry-run / execute 가능
- [x] pending / blocked / conflict ticket 실행 차단
- [x] 실행 직전 conflict guard + token 재검증
- [x] pre-validation stale revision → conflict (blocked 아님)
- [x] **update_document without baseRevision → blocked (B1 재작업)**
- [x] expired/revoked token → blocked
- [x] disabled MCP tool → dry-run/execute 차단
- [x] `create_document` / `update_document` / `move_to_trash` 실행 성공
- [x] create_document overwrite 차단
- [x] destructive = 휴지통 이동만 (영구 삭제 없음)
- [x] dry-run / execution log / audit에 민감 본문 미저장
- [x] queue 승인만으로 문서 변경 없음 (실행 시에만 변경)
- [x] **partial write rollback — create delete / update file restore (I1 재작업)**
- [x] Dashboard / Privacy execution summary 반영
- [x] Sprint 05 승인 원자성 회귀 없음
- [x] Sprint 06 active-only export 회귀 없음
- [x] Sprint 07 MCP enqueue-only 회귀 없음
- [x] 접근성: 50px 버튼, 16px 폰트, destructive 2단계 확인
- [ ] `flutter analyze` / `flutter test` (80/80) / MCP sidecar build — Codex 재실행
## 핵심 파일

- `lib/data/db/migrations.dart` (v6)
- `lib/data/services/queue_execution_service_impl.dart`
- `lib/data/services/safe_apply_service_impl.dart`
- `lib/data/services/work_queue_service_impl.dart`
- `lib/application/sac_container.dart`
- `lib/ui/screens/work_queue_panel.dart`
- `lib/ui/widgets/privacy_status_panel.dart`
- `test/sprint8_integration_test.dart`

## 실행 명령

```bash
cd app/flutter_app && flutter analyze && flutter test
cd mcp/sidecar && npm ci --ignore-scripts && npm run build
```
