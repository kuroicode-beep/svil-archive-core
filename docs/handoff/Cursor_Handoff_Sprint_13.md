# Cursor Handoff — Sprint 13 Embedded Sidecar / Tray / Autostart

> **Sprint 12B 기준**: `c2e73a4` / **재작업**: `4d49a7a`
> **Sprint 13 구현 커밋**: `(commit after push)`
> **작업지시문**: [Sprint 13 WI](https://app.notion.com/p/379864048e54815cb6a8c594fc1e0b3d)

## Sprint 13 구현 요약

- `SidecarProcessManager` — start / stop / restart / lifecycle snapshot
- 앱 시작 시 sidecar 자동 시작 **옵션** (기본 OFF)
- 창 닫기 → tray 상주 (기본 ON, `closeToTray`)
- system tray 메뉴 (열기 / sidecar 재시작·중지 / 종료)
- Windows startup folder autostart (기본 OFF, `SAC_Autostart.cmd`)
- Settings MCP/Startup UI — lifecycle 상태, 토글, 수동 제어
- `BUILD_MANIFEST.json` — `sidecar_process_managed_by_app`, `tray_resident_supported`, `windows_autostart_supported`
- `sprint13_integration_test.dart` (9항목)

## Codex에게

- `docs/handoff/Codex_Verification_Request_Sprint_13.md` 기준 검증
- tray/closeToTray/autostart 기본값 안전성 (기본 OFF / closeToTray ON)
- sidecar dispose 시 DB 미초기화 tearDown 회귀 없음
- remote MCP / external API 비활성 유지
- `flutter test` **183/183** (175 + Sprint 13 8)

## 소장님에게

- Windows 패키지에서 tray 아이콘 / 창 닫기 → tray 상주 확인
- Settings > MCP/Startup — sidecar lifecycle / autostart 토글
- smoke checklist +3항목 (자동시작 / tray / Windows autostart)
