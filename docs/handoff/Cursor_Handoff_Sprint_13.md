# Cursor Handoff — Sprint 13 Embedded Sidecar / Tray / Autostart

> **Sprint 12B 기준**: `c2e73a4` / **재작업**: `4d49a7a`
> **Sprint 13 구현 커밋**: `efa97e2`
> **manifest 정합 커밋**: `c44938a`
> **Codex 검증**: PASS (2026.06.08)
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

## Codex 최종 검증

- **판정**: PASS (`HEAD c44938a`, `flutter test` 184/184)
- **패키지**: `bin/windows/sac_v0.1.0-rc.1_windows_x64_efa97e2/`
- **Advisory**: `bin/windows`에 `4d49a7a` 패키지 공존 — 전달 ZIP은 `efa97e2`만 지정

## 소장님에게

- 전달 ZIP: **`sac_v0.1.0-rc.1_windows_x64_efa97e2.zip`** (4d49a7a 아님)
- tray 아이콘 / 창 닫기 → tray 상주 확인
- Settings > MCP/Startup — sidecar lifecycle / autostart 토글
- smoke checklist +3항목 (자동시작 / tray / Windows autostart)
