# Codex Verification Request — Sprint 16H-3

> **작업지시문**: [Sprint 16H-3 WI](https://app.notion.com/p/37a864048e548173871cd7da89cc75e4)
> **기준**: Sprint 16H-2 `1b5080d`

## 검증 범위

### Hotfix 1 — Import dry-run 결과 표시

- [ ] 한글/공백 Windows 경로 dry-run
- [ ] dry-run 결과 요약 (후보/등록 가능/skip/conflict/error)
- [ ] Markdown 0개 / 모두 skip / 오류 상태 안내
- [ ] 등록 가능 시 execute 활성화
- [ ] 고대비 모드 텍스트 가독성

### Hotfix 2 — 문서 아카이브 목록

- [ ] loading / empty / error / ready 상태 UI
- [ ] Import category 문서 목록 렌더링
- [ ] 문서 선택 → 우측 메타데이터 패널
- [ ] Import 후 목록 refresh
- [ ] 빈 회색 패널 없음

### 회귀

- [ ] Sprint 16H-2 / 16H / 16
- [ ] MCP sidecar

## 검증 명령

```bash
cd app/flutter_app
flutter analyze
flutter test test/sprint16h3_integration_test.dart
flutter test test/sprint16h2_integration_test.dart
flutter test test/sprint16h_integration_test.dart
flutter test test/sprint16_integration_test.dart

cd ../../mcp/sidecar
npm ci
npm run build
npm test
```

## 완료 보고서 제목

`✅ 검증 보고서 — SAC Sprint 16H-3 Archive Import Blocker UI Fix (Codex, 2026.06.09)`
