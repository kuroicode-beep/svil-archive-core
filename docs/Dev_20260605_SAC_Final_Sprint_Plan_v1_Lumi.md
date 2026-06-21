---
title: "SAC Final Sprint Plan v1.0"
author: "Lumi"
project: "SVIL Archive Core"
type: "Sprint Plan"
status: "fixed"
created: "2026-06-05"
updated: "2026-06-05"
version: "1.0"
encoding: "UTF-8"
tags:
  - SVIL
  - SAC
  - Sprint
  - Sonnet
  - Cursor
  - Codex
  - MCP
  - Flutter
  - Final
---

# SAC Final Sprint Plan v1.0

작성자: 루미  
작성일: 2026-06-05  
상태: Fixed / Phase 1 실행 기준 최종본  
프로젝트: SVIL Archive Core

---

## 0. 문서 목적

이 문서는 SAC Phase 1 개발을 실제 실행 가능한 스프린트 단위로 분리한 최종 계획서다.

핵심 전략은 다음이다.

```text
루미 설계 / 작업지시문
→ Sonnet 초반 골격 설계
→ Cursor 실제 구현
→ Codex 검증
→ 루미 완료보고서 / 다음 지시문
→ 소장님 최종 확인
```

---

## 1. 전체 개발 원칙

```text
Windows first, macOS every sprint.
Local first, cloud optional.
User first, AI never overwrites.
Markdown first, SQLite as brain.
TypeScript MCP sidecar fixed.
Spec rich, Phase 1 minimal.
```

### 절대 원칙

1. Phase 1에서는 고급 기능보다 안전한 코어를 우선한다.
2. Sonnet은 전체 구현자가 아니라 골격 설계자다.
3. Cursor는 기능 구현자다.
4. Codex는 검증자다.
5. 모든 스프린트 Done 기준에는 macOS smoke test가 포함된다.
6. 개인 아카이브 자동 승인은 Phase 1에서 하지 않는다.
7. sync_journal은 Phase 1에서 기록만 구현한다.
8. 외부 API는 기본 OFF다.
9. TTS는 OS System TTS 또는 Local TTS를 기본으로 한다.
10. TypeScript MCP sidecar는 확정이다.

---

## 2. 역할 정의

| 역할 | 담당 |
|---|---|
| 소장님 | 최종 의사결정, 최종 확인 |
| 루미 | 스펙 정리, 작업지시문, 핸드오프, 완료보고서, 다음 작업 분해 |
| Sonnet | 초반 아키텍처, 서비스 경계, DB schema, skeleton 설계 |
| Cursor | 실제 기능 구현, UI/서비스/DB 연결 |
| Codex | 테스트, 검증, 리스크 확인, 회귀 확인 |
| 유미 | 필요 시 문서 정리, 표현 보조 |

---

## 3. Sonnet 사용 범위

Sonnet은 Sprint 1~2에서만 핵심 투입한다.

### Sonnet에게 맡길 것

| 포함 | 설명 |
|---|---|
| 프로젝트 구조 | Flutter layer 구조, 폴더 구조 |
| 서비스 경계 | WorkspaceService, ArchiveService, QueueService 등 |
| 도메인 모델 | Document, Workspace, SyncState, Ticket 등 |
| SQLite schema draft | Phase 1 테이블 초안 |
| MCP contract | TypeScript sidecar tool contract |
| Architecture Note | Cursor가 이어받을 구조 설명 |
| Minimal skeleton | 실행 가능한 최소 앱 골격 |

### Sonnet에게 맡기지 않을 것

| 제외 | 이유 |
|---|---|
| 전체 UI 완성 | Cursor 단계에서 구현 |
| 개인 아카이브 전체 구현 | Sprint 7에서 구현 |
| 외부 API 연동 완성 | Sprint 8에서 구현 |
| 복잡한 sync_journal 복구 | Phase 2 이후 |
| 자동 승인 규칙 | Phase 1 제외 |
| 벡터 검색 | Phase 2 이후 |
| 모든 다국어 번역 | 구조만 준비 |

---

## 4. 전체 Sprint 개요

| Sprint | 담당 | 핵심 목표 |
|---|---|---|
| Sprint 0 | 루미 | 시작 패키지 준비 |
| Sprint 1 | Sonnet | Architecture Skeleton |
| Sprint 2 | Sonnet | Minimal Vertical Slice |
| Sprint 3 | Cursor + Codex | Document Archive 구현 |
| Sprint 4 | Cursor + Codex | Search / Trash / Sync |
| Sprint 5 | Cursor + Codex | TypeScript MCP Sidecar |
| Sprint 6 | Cursor + Codex | Conflict / Queue / Capability |
| Sprint 7 | Cursor + Codex | Personal Archive / Extraction Queue |
| Sprint 8 | Cursor + Codex | LLM / API / Privacy / TTS Policy |
| Sprint 9 | Cursor + Codex | Dashboard / Theme / TTS / i18n |
| Sprint 10 | Cursor + Codex | Hardening / Packaging / Final QA |

---

## 5. Sprint 0 — 루미 시작 패키지 준비

### 담당

루미

### 목표

Sonnet이 Sprint 1에서 바로 작업할 수 있도록 컨텍스트 패키지를 준비한다.

### 입력 문서

- SAC Final Specification v1.0
- SAC Final Design Instruction v1.0
- SAC Final Sprint Plan v1.0
- SVIL AI Collaboration Guide

### 작업 내용

1. Sonnet용 작업지시문 작성
2. Phase 1 최소 구현 범위 재확인
3. Sonnet 금지 범위 명시
4. 출력 산출물 형식 지정
5. Architecture Note 요구사항 작성
6. Cursor handoff 요구사항 작성

### 산출물

- Sonnet Sprint 1 작업지시문
- Sonnet 출력 템플릿
- Cursor Handoff 템플릿

### Done 기준

- Sonnet이 읽고 바로 시작할 작업지시문이 존재한다.
- “전체 구현 금지 / skeleton만” 원칙이 명시되어 있다.
- Phase 1 제외 항목이 명시되어 있다.

---

## 6. Sprint 1 — Sonnet Architecture Skeleton

### 담당

Sonnet

### 목표

SAC 전체 구조의 뼈대를 만든다.

앱이 완성될 필요는 없다.  
중요한 것은 Cursor가 이어받을 수 있는 명확한 구조다.

### 구현 범위

| 영역 | 작업 |
|---|---|
| Flutter 구조 | 앱 실행 가능한 기본 프로젝트 구조 |
| Layering | domain / application / infrastructure / presentation 분리 |
| Workspace | WorkspaceService interface |
| Archive | ArchiveService interface |
| Database | DatabaseService interface |
| Queue | DatabaseWriteQueue / IndexingQueue / LlmJobQueue interface |
| Sync | SyncState model, revision model |
| Document | Document, DocumentMetadata, DocumentContent model |
| Settings | AppSettings model |
| Theme | ThemeToken, DensityToken, ThemeService skeleton |
| Accessibility | HighContrast toggle state skeleton |
| TTS | TtsService interface only |
| MCP | TypeScript sidecar folder, contract draft 위치 |
| i18n | locale resource folder 구조 |
| Startup | launch_at_startup settings field |
| Testing | unit test folder structure |

### 만들 파일 예시

```text
/lib
  /domain
    /models
    /repositories
  /application
    /services
    /queues
  /infrastructure
    /database
    /filesystem
    /mcp
    /settings
  /presentation
    /screens
    /widgets
    /theme
/mcp-sidecar
  /src
    tools.ts
    server.ts
    contracts.ts
/test
/docs
  Architecture_Note.md
  Service_Contracts.md
```

### Sonnet 금지 사항

- 완성형 UI 구현 금지
- 개인 아카이브 전체 구현 금지
- 외부 API 실제 연동 금지
- MCP 서버 완성형 구현 금지
- sync_journal 복구 엔진 구현 금지
- 자동 승인 규칙 구현 금지
- 과도한 추상화 금지

### 산출물

- 실행 가능한 Flutter skeleton
- Architecture Note
- Module Map
- Service Contracts
- DB Schema Draft
- MCP Contract Draft
- Known Risks
- Cursor Handoff

### Windows Done 기준

- Flutter 앱 실행 가능
- 3패널 placeholder 표시
- 기본 ThemeService skeleton 존재
- WorkspaceService interface 존재
- ArchiveService interface 존재
- Queue interfaces 존재
- docs 폴더에 Architecture Note 존재

### macOS Smoke Test

- macOS에서 Flutter build 시도
- macOS 경로 관련 하드코딩 여부 확인
- sidecar 경로가 platform adapter로 분리되어 있는지 확인

### Codex 검증 포인트

- 구조가 과도하게 복잡하지 않은지
- 서비스 경계가 불명확하지 않은지
- OS 경로 하드코딩이 없는지
- Phase 1 제외 항목을 구현하려고 하지 않았는지

---

## 7. Sprint 2 — Sonnet Minimal Vertical Slice

### 담당

Sonnet

### 목표

Workspace → Markdown → SQLite → UI 표시까지 최소 흐름을 연결한다.

### 구현 범위

| 영역 | 작업 |
|---|---|
| Workspace | 기본 Workspace 생성/선택 skeleton |
| Markdown | 샘플 문서 생성/읽기 |
| SQLite | `workspaces`, `documents`, `sync_state` 테이블 생성 |
| ArchiveService | create/read/update 최소 동작 |
| UI | 문서 목록 + 문서 보기 placeholder |
| Sync | 최소 frontmatter, content_hash, revision 저장 |
| sync_journal | append-only 로그 기록만 |
| Theme | Friendly Light / Dark / High Contrast 구조 |
| Density | Comfortable 기본값 |
| TTS | 버튼과 service 호출 stub |
| MCP | contract만, 실제 tool 일부 stub |

### Phase 1 제한

- sync_journal 기반 복구 구현하지 않음
- 개인 아카이브 자동 추출 구현하지 않음
- 외부 API 연결하지 않음
- UI polish 하지 않음

### 산출물

- Minimal vertical slice
- Updated Architecture Note
- DB migration draft
- Cursor Handoff for Sprint 3

### Windows Done 기준

- 기본 Workspace가 생성됨
- 샘플 Markdown 문서를 만들 수 있음
- SQLite에 문서 메타데이터가 저장됨
- 앱에서 문서 목록을 볼 수 있음
- 문서 선택 시 내용을 볼 수 있음
- 고대비 토글 state가 UI에 반영되는 skeleton이 있음
- TTS 버튼이 존재함
- sync_journal에 append-only 로그가 기록됨

### macOS Smoke Test

- macOS에서 Workspace 생성 경로 확인
- SQLite 파일 생성 확인
- Markdown 파일 생성/읽기 확인
- 줄바꿈/UTF-8 문제 확인

### Codex 검증 포인트

- Markdown과 SQLite 관계가 스펙과 맞는지
- sync_journal이 기록만 하는지
- frontmatter가 과도하지 않은지
- UI thread를 막는 동작이 없는지

### Sonnet 종료 게이트

Sprint 2 종료 후 Sonnet은 메인 구현에서 빠진다.

반드시 받아야 할 문서:

1. Architecture Note
2. Module Map
3. Service Contracts
4. DB Schema Draft
5. MCP Contract Draft
6. Known Issues
7. Cursor Handoff

---

## 8. Sprint 3 — Cursor Document Archive 구현

### 담당

Cursor 구현 / Codex 검증 / 루미 지시문 정리

### 목표

문서 아카이브 기능을 실제 사용 가능한 수준으로 구현한다.

### 주요 작업

- Markdown 문서 생성
- Markdown 문서 읽기
- Markdown 문서 수정
- 문서 메타데이터 편집
- 폴더 트리 사이드바
- 우측 컨텍스트 패널 기본
- 문서 목록 UI
- 문서 상세 UI
- Friendly Light 기본 적용
- High Contrast 하단 토글 UI 연결
- density token 적용

### 주요 파일 영역

```text
/lib/application/services/archive_service.dart
/lib/infrastructure/filesystem/markdown_file_store.dart
/lib/infrastructure/database/document_repository.dart
/lib/presentation/screens/document_archive_screen.dart
/lib/presentation/widgets/sidebar.dart
/lib/presentation/widgets/context_panel.dart
```

### Done 기준

- 문서를 생성/수정/저장할 수 있다.
- 문서 목록과 폴더 트리가 표시된다.
- 문서 선택 시 본문이 표시된다.
- Friendly Light가 기본으로 적용된다.
- High Contrast toggle이 UI에 존재한다.
- density token이 컴포넌트에 적용된다.

### macOS Smoke Test

- 문서 생성 경로 확인
- 한글 파일명 / UTF-8 확인
- 폴더 트리 표시 확인

### Codex 검증

- 경로 하드코딩 여부
- UTF-8 문제
- Markdown 저장 안정성
- UI density token 누락 여부
- Theme token 직접 색상 하드코딩 여부

---

## 9. Sprint 4 — Cursor Search / Trash / Sync

### 담당

Cursor 구현 / Codex 검증

### 목표

검색, 휴지통, sync 상태 관리를 구현한다.

### 주요 작업

- document_chunks
- document_fts
- FTS5 검색
- 검색 화면
- 휴지통 이동
- 휴지통 복구
- 활성 DB에서 휴지통 문서 제거
- 복구 시 DB 재인덱싱
- sync_state 업데이트
- dirty / clean / conflict 표시
- IndexingQueue debounce / batch 적용

### Done 기준

- 검색어로 문서를 찾을 수 있다.
- 문서를 휴지통으로 이동할 수 있다.
- 휴지통 이동 시 검색 결과에서 제외된다.
- 복구 시 다시 검색된다.
- sync 상태가 UI에 표시된다.
- IndexingQueue가 debounce를 사용한다.
- 대량 인덱싱이 UI thread를 막지 않는다.

### macOS Smoke Test

- SQLite FTS 동작 확인
- 파일 이동/복구 경로 확인
- 휴지통 경로 권한 확인

### Codex 검증

- 삭제 후 활성 DB 제거 확인
- 복구 후 재인덱싱 확인
- debounce 누락 확인
- batch 처리 여부 확인
- UI freeze 가능성 확인

---

## 10. Sprint 5 — Cursor TypeScript MCP Sidecar

### 담당

Cursor 구현 / Codex 검증

### 목표

TypeScript Local MCP Server sidecar를 Flutter 앱과 연결한다.

### 주요 작업

- TypeScript MCP server 기본 구현
- stdio transport
- Flutter에서 sidecar 실행
- MCP status 표시
- 기본 read tools
- 기본 write request tools
- MCP tool on/off 설정
- MCP 호출 로그
- TypeScript build script

### 기본 tools

- list_documents
- get_document
- create_document
- update_document
- search_documents
- get_document_tree
- move_document_to_trash
- restore_document_from_trash
- get_settings

### Done 기준

- MCP sidecar가 실행된다.
- Flutter 앱에서 MCP 상태를 표시한다.
- MCP tool로 문서를 읽을 수 있다.
- MCP tool로 문서 생성 요청이 가능하다.
- tool off 상태에서 호출이 차단된다.
- MCP 이벤트가 기록된다.

### macOS Smoke Test

- macOS에서 sidecar 실행 경로 확인
- stdio 연결 확인
- Node/packaging 관련 문제 기록

### Codex 검증

- MCP tool이 ArchiveService를 우회하지 않는지
- tool off 상태가 지켜지는지
- sidecar 경로가 OS별 adapter를 쓰는지
- TypeScript 빌드 산출물 관리가 명확한지

---

## 11. Sprint 6 — Cursor Conflict / Queue / Capability

### 담당

Cursor 구현 / Codex 검증

### 목표

동시 쓰기 충돌, DatabaseWriteQueue, 작업큐, capability token을 구현한다.

### 주요 작업

- DatabaseWriteQueue 구현
- AI write 요청 ticket 등록
- revision 충돌 감지
- AI 덮어쓰기 차단
- AI 수정 시 새 문서/새 version 생성
- conflict 상태 표시
- capability token metadata
- token scope / TTL
- destructive action 재확인
- 작업큐 UI
- 승인 카드 UI
- diff 보기 진입점

### Done 기준

- 오래된 revision 기준 AI 수정이 차단된다.
- AI 수정은 기존 문서를 덮지 않는다.
- write capability 없이는 수정할 수 없다.
- destructive 작업은 별도 확인이 필요하다.
- 작업큐에 AI 작업이 표시된다.
- 사용자 직접 작업이 우선 처리된다.

### macOS Smoke Test

- capability metadata 저장 확인
- 작업큐 DB 동작 확인
- 파일 lock 관련 OS 차이 확인

### Codex 검증

- token이 LLM 프롬프트에 노출되지 않는지
- DatabaseWriteQueue 우회 쓰기가 없는지
- conflict 처리 정책이 스펙과 맞는지
- UI 승인 카드가 실제 작업과 연결되는지

---

## 12. Sprint 7 — Cursor Personal Archive / Extraction Queue

### 담당

Cursor 구현 / Codex 검증

### 목표

문서 아카이브와 분리된 개인 아카이브, 추출 대기열, 수동 승인 흐름을 구현한다.

### 주요 작업

- 개인 아카이브 화면
- Manual Profile
- Memory Comment
- personal_archive_categories
- personal_extraction_queue
- 민감도 라벨 Low / Medium / High
- 승인 / 수정 / 거절 / 나중에
- 승인된 항목 저장
- 개인 아카이브 검색
- 문서 아카이브와 UI/DB 분리

### Phase 1 제한

- 자동 승인 구현 금지
- 민감도는 보조 라벨로만 사용
- Low risk 자동 승인도 구현하지 않음

### Done 기준

- 개인 프로필을 입력할 수 있다.
- 일지 코멘트를 작성할 수 있다.
- 문서에서 개인 데이터 후보가 대기열에 저장된다.
- 모든 후보는 수동 승인 상태다.
- 승인/수정/거절/나중에 처리가 가능하다.
- 승인된 항목만 개인 아카이브에 저장된다.

### macOS Smoke Test

- 개인 아카이브 DB 테이블 동작 확인
- 한글/다국어 텍스트 저장 확인

### Codex 검증

- 개인 데이터가 바로 확정 저장되지 않는지
- 자동 승인 코드가 없는지
- local-only 필드가 보호되는지
- 문서 아카이브와 개인 아카이브 쿼리가 분리되어 있는지

---

## 13. Sprint 8 — Cursor LLM / API / Privacy / TTS Policy

### 담당

Cursor 구현 / Codex 검증

### 목표

Ollama, API 설정, 개인정보 보호, 외부 전송 preflight, TTS 정책을 구현한다.

### 주요 작업

- Ollama 연결 상태
- 문서 요약/추출 API 설정
- 개인 아카이브 분석 API 설정
- 외부 API 기본 OFF
- 외부 전송 preflight UI
- 전송 대상 텍스트 미리보기
- 민감도 라벨 표시
- audit log 기록
- LLM용 자기정보 문서 생성
- 나에 대해 이야기하기 / 질문하기 skeleton
- OS System TTS / Local TTS 기본
- 외부 TTS 기본 OFF
- TTS 컨트롤바
- 현재 문장 하이라이트

### Done 기준

- Ollama 상태를 표시할 수 있다.
- 문서 요약/추출 API와 개인 분석 API 설정이 분리되어 있다.
- 외부 API는 기본 OFF다.
- 외부 전송 전 확인 화면이 나온다.
- audit log가 저장된다.
- TTS가 로컬/시스템 엔진으로 재생된다.
- 외부 TTS는 기본 OFF다.

### macOS Smoke Test

- macOS System TTS 동작 확인
- API key 저장 경로 확인
- audit log 저장 확인

### Codex 검증

- 외부 API 기본 OFF 확인
- 전송 전 확인 누락 여부
- 민감 정보 포함 문서 TTS 정책 확인
- API 설정 분리 확인

---

## 14. Sprint 9 — Cursor Dashboard / Theme / i18n

### 담당

Cursor 구현 / Codex 검증

### 목표

SAC의 실제 사용 화면을 완성한다.

### 주요 작업

- 메인 대시보드
- AI 협업 프로토콜 카드
- Critical / conflict 알림
- 최근 키워드 해시태그
- 최근 활동
- 작업큐 요약
- 개인정보 보호 상태 카드
- Friendly Light polish
- Dark Mode
- High Contrast Mode
- Pink / Yellow / Blue preset
- 하단 고대비 토글 전체 화면 적용
- density token 전체 점검
- i18n resource 구조
- ko/en 우선 리소스
- fallback 정책
- 언어 설정 화면
- 시작 시 실행 설정 UI

### Done 기준

- 대시보드에서 AI 협업 현황이 보인다.
- 개인정보 보호 상태가 보인다.
- 모든 주요 화면에서 고대비 토글이 동작한다.
- Friendly Light / Dark / High Contrast 전환 가능하다.
- density token이 전체 UI에 적용된다.
- i18n 구조가 존재한다.
- 한국어/영어 기본 리소스가 있다.
- 시작 시 실행 옵션 UI가 있다.

### macOS Smoke Test

- 테마 전환 확인
- 언어 리소스 로딩 확인
- 시작 시 실행 옵션 UI 확인
- 화면 깨짐 확인

### Codex 검증

- 색상 하드코딩 여부
- 고대비 모드 대비 부족 여부
- 상태가 색상만으로 전달되는지 확인
- i18n 누락 시 fallback 확인

---

## 15. Sprint 10 — Hardening / Packaging / Final QA

### 담당

Cursor 구현 / Codex 검증 / 루미 완료보고서 / 소장님 최종 확인

### 목표

Phase 1을 안정화하고 배포 전 상태로 정리한다.

### 주요 작업

- Windows packaging 초안
- macOS packaging 검토
- 경로 처리 최종 점검
- SQLite migration 검증
- DB 손상 시 재스캔 테스트
- sync_journal 기록 확인
- 검색 성능 기본 테스트
- 대량 문서 fixture 테스트
- MCP sidecar 실행 안정성 확인
- 로그 파일 정리
- 개인정보 보호 UX 점검
- 접근성 점검
- TTS 점검
- 문서화 정리

### Done 기준

- Windows에서 앱 실행 가능
- macOS에서 smoke build/test 통과
- Workspace 생성/문서 CRUD/검색/휴지통/MCP/TTS/테마가 동작
- 개인 데이터 후보는 수동 승인만 가능
- 외부 API 기본 OFF
- 주요 작업 로그가 남음
- 완료보고서 작성 완료

### Codex Final 검증

- Phase 1 필수 구현 범위 충족 여부
- Phase 1 제외 항목이 들어오지 않았는지
- 보안/프라이버시 기본값 확인
- macOS smoke test 결과 확인
- 문서화 누락 확인

---

## 16. 매 Sprint 공통 체크리스트

각 Sprint 완료 시 반드시 확인한다.

| 항목 | 확인 |
|---|---|
| Windows 실행 | 필수 |
| macOS smoke test | 필수 |
| UTF-8 | 필수 |
| 경로 하드코딩 없음 | 필수 |
| 사용자 수정 우선 | 필수 |
| AI 덮어쓰기 없음 | 필수 |
| 외부 API 기본 OFF | 필수 |
| local-only 데이터 보호 | 필수 |
| Theme token 사용 | 필수 |
| Density token 사용 | 필수 |
| 로그 기록 | 필수 |
| 완료보고서 작성 | 필수 |

---

## 17. 작업지시문 작성 규칙

루미가 Cursor 또는 Sonnet에게 작업지시문을 작성할 때 다음 형식을 사용한다.

```md
# 작업지시문

## 목표

## 입력 문서

## 구현 범위

## 구현 금지 범위

## 수정 가능 파일

## 생성 필요 파일

## 완료 기준

## 테스트 기준

## macOS smoke test 기준

## 결과보고서 형식
```

---

## 18. 결과보고서 형식

각 AI는 작업 후 결과보고서를 작성한다.

```md
# 결과보고서

## 작업 요약

## 변경 파일

## 구현 완료 항목

## 미완료 항목

## 발견 이슈

## 테스트 결과

## macOS smoke test 결과

## 다음 작업 제안

## Critical 여부
```

---

## 19. 완료보고서 형식

루미는 각 Sprint 종료 후 완료보고서를 작성한다.

```md
# 완료보고서

## Sprint

## 원본 작업지시문

## 결과보고서 요약

## Codex 검증 요약

## 완료 항목

## 남은 항목

## 다음 Sprint 핸드오프

## 소장님 확인 필요 항목
```

---

## 20. 최종 고정 판단

SAC Phase 1은 이제 설계 검토를 멈추고 실행 단계로 들어간다.

추가 리스크가 발견되더라도 다음 원칙을 따른다.

1. Phase 1을 흔드는 구조 변경은 하지 않는다.
2. 치명적 데이터 손실/보안 이슈만 즉시 반영한다.
3. 나머지는 Phase 2 후보로 기록한다.
4. 개발 중 문제는 작업지시문, 결과보고서, 완료보고서로 관리한다.

한 줄 결론:

> Sonnet은 골격만 잡고, Cursor가 구현하며, Codex가 검증한다. SAC Phase 1의 목표는 많은 기능이 아니라 안전한 로컬 AI 협업 코어의 완성이다.

— 루미
