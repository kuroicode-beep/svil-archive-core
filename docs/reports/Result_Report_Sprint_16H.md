---
title: "Result Report — SAC Sprint 16H Emergency Hotfix"
author: "Cursor"
created: "2026-06-09"
sprint16r_base_commit: "5a2d99b"
---

# 완료 보고서 — SAC Sprint 16H Emergency UI / Settings / Ollama Model Fix

> **작업지시문**: [Dev_20260609_SAC_Work_Instruction_16H_Emergency_UI_Settings_Ollama_Model_Fix_v1_Lumi](https://app.notion.com/p/379864048e54819ab883fd92ac0305dd)

## 01. 작업 요약

- **목표**: 실사용 막힘 3건 (감시 폴더 변경, 스크롤 튐, Ollama 모델 선택) 긴급 수정
- **결과**: ✅ 구현 완료 — Codex 검증 대기
- **기준**: Sprint 16R PASS `5a2d99b`

## 02. 구현 결과

✅ Settings/Git Sync **감시 폴더 변경** + **기본 Downloads 복원**  
✅ 토글 저장 시 전체 로딩 스피너 제거 → scroll position 유지  
✅ `ollamaModel` 저장 + 모델 목록 새로고침 + 선택 dropdown  
✅ 폴더 변경 시 watcher 재시작 (queue 유지)  
✅ `sprint16h_integration_test` 10/10 + `sprint16` 24/24 회귀  

## 03. 변경 파일

| 파일 | 변경 |
|------|------|
| `settings.dart` | `ollamaModel` 필드 |
| `settings_service_impl.dart` | `ollama_model` persist |
| `settings_screen.dart` | Hotfix UI + scroll |
| `git_sync_screen.dart` | 폴더 변경 카드 |
| `main_shell.dart` | downloads callback |
| `sac_container.dart` | watcher restart |
| `download_watcher_service_impl.dart` | default folder helper |
| `test/sprint16h_integration_test.dart` | 신규 |

## 04. Git 커밋

- (push 후 기록)

## 05. 핸드오프

- **Codex**: `docs/handoff/Codex_Verification_Request_Sprint_16H.md`
- **소장님**: Settings/Git Sync 폴더 변경 + Ollama 모델 선택 + 토글 스크롤 smoke
