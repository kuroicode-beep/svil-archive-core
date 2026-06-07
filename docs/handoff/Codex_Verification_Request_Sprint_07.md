# Codex Verification Request — Sprint 07

> **Sprint 06 기준 커밋**: `df0121e`
> **범위**: MCP Bridge / Work Queue / Conflict Guard

## 검증 항목

- [ ] AI/MCP write request가 직접 실행되지 않는지
- [ ] queue ticket 등록 우선 정책이 지켜지는지
- [ ] destructive action이 승인 전 실행되지 않는지
- [ ] tool on/off 설정이 작동하는지 (기본 off)
- [ ] conflict guard: stale revision / path traversal / trashed write 차단
- [ ] 외부 API 호출 또는 remote MCP 노출 없음
- [ ] audit log에 민감 본문이 남지 않는지
- [ ] Sprint 05 승인 원자성 회귀 없음
- [ ] Sprint 06 active-only export 회귀 없음
- [ ] 접근성 기준 반영
- [ ] `baseRevision` stale MCP write → conflict ticket
- [ ] token 없는 write/destructive enqueue → blocked
- [ ] non-user approve without token → 차단
- [ ] `flutter analyze` / `flutter test` (56/56) / MCP sidecar build

## 핵심 파일

- `lib/data/db/migrations.dart` (v5)
- `lib/data/services/work_queue_service_impl.dart`
- `lib/data/services/conflict_guard_service_impl.dart`
- `lib/data/services/mcp_bridge_status_service_impl.dart`
- `lib/data/services/mcp_tool_registry_service_impl.dart`
- `lib/ui/screens/work_queue_panel.dart`
- `test/sprint7_integration_test.dart`

## 실행 명령

```bash
cd app/flutter_app && flutter analyze && flutter test
cd mcp/sidecar && npm ci --ignore-scripts && npm run build
```
