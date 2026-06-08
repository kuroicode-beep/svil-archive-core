# Codex Verification Request — Sprint 13

> **Sprint 12B 기준**: `c2e73a4`
> **Sprint 13 구현 커밋**: `(commit after push)`
> **작업지시문**: [Sprint 13](https://app.notion.com/p/379864048e54815cb6a8c594fc1e0b3d)
> **범위**: Embedded sidecar process manager / tray resident / Windows autostart

## 검증 항목

- [ ] `SidecarProcessManager` start/stop/restart + lifecycle 상태
- [ ] `autoStartSidecar` 기본 OFF — 사용자/initiated 없이 자동 launch 금지
- [ ] `closeToTray` 기본 ON — 창 닫기 시 tray 상주
- [ ] `startWithWindows` 기본 OFF — Startup folder 등록은 사용자 opt-in
- [ ] tray 메뉴 + quit 경로
- [ ] Settings MCP/Startup UI 연동
- [ ] `BUILD_MANIFEST.json` Sprint 13 flags
- [ ] `remote_mcp_enabled: false`, `external_api_enabled: false` 유지
- [ ] Sprint 05~12B 회귀
- [ ] `flutter analyze` / `flutter test` (183)
- [ ] Windows portable package 재생성 (선택)
- [ ] Git 커밋 / 로컬 완료보고서 정합

## 핵심 파일

- `lib/data/services/sidecar_process_manager_impl.dart`
- `lib/application/sac_desktop_shell.dart`
- `lib/data/services/windows_autostart_service_impl.dart`
- `lib/ui/screens/settings_screen.dart`
- `scripts/package_windows_rc.ps1`
- `test/sprint13_integration_test.dart`

## 실행 명령

```bash
cd app/flutter_app && flutter analyze && flutter test
cd mcp/sidecar && npm ci --ignore-scripts && npm run build
powershell -ExecutionPolicy Bypass -File scripts/package_windows_rc.ps1
```

## Cursor 자체 검증 (2026.06.08)

| 항목 | 결과 |
|------|------|
| `flutter analyze` | No issues |
| `flutter test` | **183/183** passed |
| MCP sidecar build | PASS |
| dispose tearDown 회귀 | PASS (DB 미초기화 시 dispose 안전) |
