# Codex Verification Request — Sprint 12B

> **Sprint 12 기준**: `9ec7e43`
> **Sprint 12B 구현 커밋**: (구현 후 갱신)
> **작업지시문**: [Sprint 12B](https://app.notion.com/p/379864048e548156954fe3603e3b864f)
> **범위**: Windows portable MCP sidecar inclusion (기능 추가 최소, 패키징 보강)

## 검증 항목

- [ ] `mcp/sidecar`가 portable package에 포함 (`dist/index.js`)
- [ ] `BUILD_MANIFEST.json` — `mcp_sidecar_included: true`, 상대 경로만
- [ ] manifest/install에 secret/token/API key 없음
- [ ] `INSTALL.txt` MCP sidecar 안내 포함
- [ ] packaged sidecar path 탐지 (exe 기준 `mcp/sidecar/dist`)
- [ ] dev fallback / not found 상태 테스트
- [ ] `remote_mcp_enabled: false`, `external_api_enabled: false` 유지
- [ ] Sprint 05~12 회귀
- [ ] `flutter analyze` / `flutter test` / MCP sidecar build
- [ ] Windows portable ZIP 재생성 성공
- [ ] Git 커밋 / 로컬 완료보고서 정합

## 핵심 파일

- `lib/domain/utils/mcp_sidecar_path_resolver.dart`
- `lib/data/services/mcp_bridge_status_service_impl.dart`
- `scripts/package_windows_rc.ps1`
- `test/sprint12b_integration_test.dart`
- `bin/windows/sac_v0.1.0-rc.1_windows_x64_9ec7e43/BUILD_MANIFEST.json`

## 실행 명령

```bash
cd app/flutter_app && flutter analyze && flutter test
cd mcp/sidecar && npm ci --ignore-scripts && npm run build
powershell -ExecutionPolicy Bypass -File scripts/package_windows_rc.ps1 -SkipFlutterBuild
```

## Cursor 자체 검증 (2026.06.08)

| 항목 | 결과 |
|------|------|
| `flutter analyze` | No issues |
| `flutter test` | **173/173** passed |
| MCP sidecar build | PASS |
| Package sidecar | `mcp/sidecar/dist/index.js` present |
| ZIP size | ~16.9 MB (node_modules 포함) |
