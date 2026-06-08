# Cursor Handoff — Sprint 12B Windows Portable MCP Sidecar

> **Sprint 12 기준**: `9ec7e43`
> **작업지시문**: [Sprint 12B WI](https://app.notion.com/p/379864048e548156954fe3603e3b864f)

## Sprint 12B 구현 요약

- `resolveMcpSidecarPath()` — exe 기준 `mcp/sidecar/dist` 우선 탐지
- MCP bridge UI — 패키지/fallback/not found 라벨 구분
- `scripts/package_windows_rc.ps1` — sidecar + production node_modules 포함 패키징
- `bin/windows/sac_v0.1.0-rc.1_windows_x64_9ec7e43/` 재생성 (sidecar 포함)

## Codex에게

- `docs/handoff/Codex_Verification_Request_Sprint_12B.md` 기준 검증
- ZIP 내 `mcp/sidecar/dist/index.js` 실존 확인
- manifest 상대 경로 / secret 미포함 / remote MCP false

## 소장님에게

- ZIP 또는 폴더로 `sac_app.exe` 실행
- Settings > MCP 상태에서 sidecar 라벨 확인
- Node.js 18+ 필요 (sidecar 수동 실행 시)
