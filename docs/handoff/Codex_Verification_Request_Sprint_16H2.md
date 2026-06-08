# Codex Verification Request — Sprint 16H-2

> **작업지시문**: [Sprint 16H-2 WI](https://app.notion.com/p/379864048e5481438e6bc11cc56be144)
> **기준**: Sprint 16H `412109b`

## 검증 범위

### Hotfix 1 — Import dry-run 후 입력 잠금

- [ ] dry-run 성공 후 파일 선택·폴더 선택·토글 활성
- [ ] dry-run 실패 후에도 입력 복구
- [ ] 동일 옵션 재 dry-run 실패 시 이전 snapshot으로 execute 불가
- [ ] 옵션 변경 시 snapshot 무효화(실행만 차단, 미리보기 유지)
- [ ] 최신 dry-run 없이 execute import 불가

### Hotfix 2 — Git repo URL 저장

- [ ] Settings repo URL 저장 + 재시작 후 유지
- [ ] Git Sync 화면 repo URL 표시 일치
- [ ] 토글 저장 시 controller URL 함께 persist
- [ ] 저장 실패 SnackBar

### 회귀

- [ ] Sprint 16 / 16R / 16H
- [ ] MCP sidecar

## 검증 명령

```bash
cd app/flutter_app
flutter analyze
flutter test test/sprint16h2_integration_test.dart
flutter test test/sprint16h_integration_test.dart
flutter test test/sprint16_integration_test.dart

cd ../../mcp/sidecar
npm ci
npm run build
npm test
```

## 완료 보고서 제목

`✅ 검증 보고서 — SAC Sprint 16H-2 DryRun Input GitRepo Save Fix (Codex, 2026.06.09)`
