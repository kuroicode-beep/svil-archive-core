# Codex Verification Request — Sprint 16H Emergency UI / Settings / Ollama

> **기준 HEAD**: `0976c1e`
> **Sprint 16R PASS**: `5a2d99b`
> **작업지시문**: [Sprint 16H WI](https://app.notion.com/p/379864048e54819ab883fd92ac0305dd)

## 검증 체크리스트

- [ ] 다운로드 감시 폴더 변경 가능 (Settings + Git Sync)
- [ ] 기본 Downloads 복원 가능
- [ ] 설정 저장/로드 (folder, ollama endpoint, ollama model)
- [ ] ON/OFF 토글 후 scroll position 유지 (수동 smoke)
- [ ] Ollama 모델 목록 로딩 (연결 시)
- [ ] 모델 선택 저장/로드
- [ ] Ollama 연결 실패 시 안전 유지
- [ ] Sprint 16/16R 회귀 없음
- [ ] Local MCP 회귀 없음

## 명령

```bash
cd app/flutter_app && flutter analyze
flutter test test/sprint16h_integration_test.dart
flutter test test/sprint16_integration_test.dart
cd ../../mcp/sidecar && npm ci && npm run build && npm test
```

## Cursor 자체 확인 (구현 완료 시점)

| 항목 | 결과 |
|------|------|
| `flutter analyze` | PASS |
| `sprint16h_integration_test` | 10/10 |
| `sprint16_integration_test` | 24/24 |
