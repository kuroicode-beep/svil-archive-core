# Codex Verification Request — Sprint 13

> **Sprint 12B 기준**: `c2e73a4`
> **Sprint 13 구현 커밋**: `efa97e2`
> **manifest 정합 HEAD**: `c44938a`
> **작업지시문**: [Sprint 13](https://app.notion.com/p/379864048e54815cb6a8c594fc1e0b3d)
> **범위**: Embedded sidecar process manager / tray resident / Windows autostart

## 검증 항목

- [x] `SidecarProcessManager` start/stop/restart + lifecycle 상태
- [x] `autoStartSidecar` 기본 OFF — 사용자/initiated 없이 자동 launch 금지
- [x] `closeToTray` 기본 ON — 창 닫기 시 tray 상주
- [x] `startWithWindows` 기본 OFF — Startup folder 등록은 사용자 opt-in
- [x] tray 메뉴 + quit 경로
- [x] Settings MCP/Startup UI 연동
- [x] `BUILD_MANIFEST.json` Sprint 13 flags
- [x] `remote_mcp_enabled: false`, `external_api_enabled: false` 유지
- [x] Sprint 05~12B 회귀
- [x] `flutter analyze` / `flutter test` (184)
- [x] Windows portable package 재생성
- [x] Git 커밋 / 로컬 완료보고서 정합

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
| `flutter test` | **184/184** passed |
| MCP sidecar build | PASS |
| dispose tearDown 회귀 | PASS (DB 미초기화 시 dispose 안전) |
| Package | `sac_v0.1.0-rc.1_windows_x64_efa97e2` |

## Codex 최종 검증 (2026.06.08)

- **판정**: PASS / 배포 가능 YES (코드·패키지·테스트 기준)
- **HEAD**: `c44938a`
- **구현 커밋**: `efa97e2`
- **패키지**: `bin/windows/sac_v0.1.0-rc.1_windows_x64_efa97e2/`
- manifest commit `efa97e2`, Sprint 13 flags 3종, secret/절대경로 없음
- ZIP 내 `sac_app.exe`, `INSTALL.txt`, `BUILD_MANIFEST.json`, `mcp/sidecar/dist/index.js`, production `node_modules` 포함
- **Advisory**: `bin/windows`에 `4d49a7a` 패키지 공존 — 소장님 전달은 `efa97e2` ZIP만
- **소장님 smoke**: tray 상주 / Windows autostart는 OS shell 실제 동작 — Windows smoke 최종 확인 필요
