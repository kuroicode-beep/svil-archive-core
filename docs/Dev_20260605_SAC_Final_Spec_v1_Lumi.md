---
title: "SAC Final Specification v1.0"
author: "Lumi"
project: "SVIL Archive Core"
type: "Technical Specification"
status: "fixed"
created: "2026-06-05"
updated: "2026-06-05"
version: "1.0"
encoding: "UTF-8"
tags:
  - SVIL
  - SAC
  - Archive-Core
  - MCP
  - Flutter
  - SQLite
  - Local-First
  - Personal-Archive
  - Privacy
  - Accessibility
  - Final
---

# SAC Final Specification v1.0

작성자: 루미  
작성일: 2026-06-05  
상태: Fixed / Phase 1 기준 최종본  
프로젝트: SVIL Archive Core

---

## 0. 문서 목적

이 문서는 SVIL Archive Core, 이하 SAC의 Phase 1 개발 기준 최종 스펙문서다.

본 문서는 다음 원칙을 따른다.

1. 장기 설계와 리스크 대응책은 스펙에 모두 기술한다.
2. Phase 1에서는 최소 구현 범위를 별도로 제한한다.
3. 기능을 과도하게 확장하지 않고, 이후 확장이 가능한 안전한 골격을 만든다.
4. Sonnet, Cursor, Codex가 각각 이어받아도 문맥이 끊기지 않도록 한다.

---

## 1. 한 줄 정의

SAC는 로컬 Markdown Workspace를 원본으로 유지하면서 SQLite를 검색·맥락·개인 아카이브 두뇌로 사용하고, TypeScript 기반 Local MCP Server를 통해 LLM과 AI 도구가 문서를 안전하게 읽고 쓰고 수정하고 검색할 수 있게 하는 로컬 우선 AI 통신 프로토콜 기반 아카이브 앱이다.

---

## 2. 핵심 정체성

SAC는 단순 Markdown 편집기나 문서 보관 앱이 아니다.

SAC의 핵심은 **AI 통신 프로토콜 허브**다.

SAC는 다음 흐름을 지원한다.

1. 사용자가 Markdown 문서를 작성한다.
2. SAC가 Markdown 문서를 SQLite에 인덱싱한다.
3. AI가 MCP를 통해 문서를 읽고 작업한다.
4. 작업지시문, 결과보고서, 완료보고서, 검증보고서, 핸드오프 문서를 중심으로 AI 협업이 진행된다.
5. 문서에서 개인 관련 후보를 추출한다.
6. 추출 후보는 개인 아카이브 대기열에 들어간다.
7. 사용자가 승인한 항목만 개인 아카이브에 저장된다.
8. 사용자는 개인 아카이브를 기반으로 LLM용 자기정보 문서를 생성하거나 자신에 대해 질문할 수 있다.

---

## 3. 핵심 원칙

```text
Markdown = Source of Truth
SQLite   = Index / Context / Search Brain
MCP      = AI Communication Protocol
Workspace = Local Backup Unit
User     = Final Decision Maker
```

- Markdown 파일은 원본이다.
- SQLite는 원본을 대체하지 않는다.
- SQLite는 검색, 인덱스, 맥락 저장, 개인 아카이브, 로그, 설정 관리에 사용한다.
- SQLite가 손상되어도 Markdown Workspace를 다시 스캔해 재생성 가능해야 한다.
- 사용자가 직접 수정한 내용은 항상 우선한다.
- AI는 사용자 수정본을 임의로 덮어쓸 수 없다.
- 개인 데이터는 기본적으로 로컬에서만 처리한다.
- 외부 API 사용 시 전송 전 확인과 명시적 동의를 거친다.
- 백엔드 없이 로컬만으로 기본 동작이 완료되어야 한다.
- 고급 자동화는 Phase 1에서 무리하게 구현하지 않는다.

---

## 4. v1.0 / Phase 1 목표

SAC Phase 1의 목표는 완성형 지식관리 앱이 아니라, 안전하고 확장 가능한 로컬 AI 협업 아카이브 코어를 만드는 것이다.

### Phase 1 핵심 목표

- Flutter 기반 Windows 우선 데스크톱 앱
- macOS 매 스프린트 smoke test 병행
- 기본 Workspace 생성 및 선택
- Markdown 문서 CRUD
- SQLite 인덱싱
- FTS5 기본 검색
- 휴지통 이동/복구
- TypeScript Local MCP Server sidecar
- MCP tool on/off
- 사용자 우선 sync / conflict 정책
- DatabaseWriteQueue / IndexingQueue / LlmJobQueue 기본 구조
- 문서 아카이브와 개인 아카이브 분리
- 개인 데이터 추출 대기열
- 모든 개인 추출 후보 수동 승인
- 개인정보 보호 메뉴
- Friendly Light 기본 테마
- Dark / High Contrast / Custom color preset
- 하단 고대비 토글
- 시스템 또는 로컬 TTS 기본
- 다국어 구조 준비
- Windows/macOS 시작 시 실행 옵션

---

## 5. 기술 결정사항

| 항목 | 결정 |
|---|---|
| 앱 프레임워크 | Flutter |
| 1차 개발 OS | Windows |
| 2차 지원 OS | macOS |
| macOS 검증 | 매 스프린트 smoke test |
| 모바일 | Android / iOS 추후 확장 |
| MCP 방식 | Local MCP Server |
| MCP 실행 방식 | Desktop sidecar |
| MCP 구현 언어 | TypeScript 확정 |
| MCP transport | stdio 우선 |
| 문서 원본 | Markdown |
| DB | SQLite |
| SQLite 모드 | WAL mode |
| DB 위치 | Workspace 내부 |
| 기본 Workspace | 내문서/SAC DOCS |
| 문서 트리 기준 | 폴더 기준 |
| 인코딩 | UTF-8 고정 |
| 경로 저장 | Workspace 기준 상대경로 우선 |
| 삭제 정책 | 휴지통 이동 + 활성 DB 즉시 삭제 |
| 복구 정책 | Markdown 재스캔 + 최소 frontmatter + sync_journal 보조 |
| 동시 쓰기 제어 | revision + sync_state + WriteQueue |
| 다수 AI 제어 | ticket 기반 작업큐 + capability token |
| 기본 테마 | Friendly Light |
| 다크 모드 | 일반 Dark Mode |
| 고대비 모드 | Black + Yellow 중심 |
| TTS 기본 | OS System TTS 또는 Local TTS |
| 외부 API 기본값 | OFF |

---

## 6. Workspace 설계

### 6.1 기본 정책

- SAC는 Workspace 단위로 문서를 관리한다.
- 기본 Workspace는 `내문서/SAC DOCS`이다.
- Workspace 내부에 Markdown 문서, SQLite DB, 설정, 휴지통, 로그, 큐 정보를 둔다.
- Workspace 전체를 압축하면 전체 백업이 가능해야 한다.
- DB가 손상되어도 Markdown 폴더를 기준으로 재구성 가능해야 한다.

### 6.2 Workspace 구조

```text
SAC DOCS/
├── documents/
│   ├── Dev/
│   ├── Log/
│   ├── Idea/
│   ├── Research/
│   ├── Blog/
│   ├── Novel/
│   ├── YT/
│   ├── Resource/
│   └── IB/
│
└── .sac/
    ├── sac.sqlite
    ├── settings.json
    ├── trash/
    ├── backups/
    ├── logs/
    ├── queue/
    ├── mcp/
    └── sync_journal/
```

---

## 7. Markdown / SQLite 관계

### 7.1 기본 구조

Markdown은 원본이고 SQLite는 인덱스와 맥락 두뇌다.

SQLite에는 다음 정보를 저장한다.

- 문서 메타데이터
- 검색 chunk
- FTS 인덱스
- sync_state
- 개인 아카이브
- 작업큐
- MCP 이벤트
- audit log
- 설정

### 7.2 Markdown frontmatter 최소화

파일 I/O 오버헤드를 줄이기 위해 Markdown frontmatter에는 최소 복구 메타데이터만 저장한다.

```yaml
sac_id: "document-uuid"
sac_schema: "1.0"
content_hash: "sha256..."
last_known_revision: 12
last_indexed_at: "2026-06-05T12:00:00+09:00"
source_workspace: "workspace-uuid"
```

상세 sync 정보는 SQLite의 `sync_state`에서 관리한다.

### 7.3 sync_journal

SAC는 `.sac/sync_journal/`에 append-only 방식으로 주요 변경 이벤트를 기록한다.

Phase 1에서는 sync_journal을 **기록용 로그**로만 구현한다.

Phase 1에서 하지 않는 것:

- sync_journal 기반 정밀 복구 엔진
- 복잡한 conflict replay
- 변경 단위 diff 재구성

Phase 1 복구는 Markdown frontmatter, content_hash, last_known_revision, SQLite 재스캔을 기준으로 처리한다.

---

## 8. 문서 아카이브와 개인 아카이브 분리

### 8.1 분리 원칙

| 영역 | 역할 |
|---|---|
| 문서 아카이브 | Markdown 원본, 문서 메타데이터, 검색, 태그, 요약, 카테고리 |
| 개인 아카이브 | 사용자 프로필, 일지 코멘트, 승인된 개인 데이터, 개인 분석 대화 |
| 추출 대기열 | 자동 추출된 개인 데이터 후보의 승인 전 보관 영역 |

문서 아카이브와 개인 아카이브는 UI, DB, 권한 흐름에서 분리한다.

### 8.2 개인 데이터 추출 흐름

```text
문서 저장
→ 문서 아카이브 인덱싱
→ 개인 관련 후보 추출
→ 민감도 라벨 부여
→ personal_extraction_queue 저장
→ 사용자 승인 / 수정 / 거절 / 나중에
→ 승인된 항목만 personal_archive_items 저장
```

### 8.3 Phase 1 승인 정책

Phase 1에서는 모든 개인 아카이브 추출 후보를 수동 승인 대상으로 처리한다.

- Low / Medium / High 민감도는 자동 승인 기준이 아니라 검토 보조 라벨이다.
- 자동 승인은 Phase 1에서 구현하지 않는다.
- Low risk 자동 승인은 v1.1 이후 추출 정확도 검증 후 도입한다.

---

## 9. 동시 쓰기 충돌 처리

### 9.1 기본 원칙

SAC는 사용자와 AI가 같은 Markdown 문서를 동시에 수정할 수 있는 상황을 전제로 한다.

- 사용자 직접 수정본을 최우선으로 보호한다.
- AI는 사용자가 수정한 최신 문서를 임의로 덮어쓸 수 없다.
- AI가 오래된 문서 상태를 기준으로 수정하려는 경우 기존 문서를 덮어쓰지 않고 새 문서 또는 새 버전으로 작성한다.
- 충돌 발생 시 사용자는 병합 옵션을 선택할 수 있다.

### 9.2 sync_state

상세 sync 상태는 SQLite의 `sync_state` 테이블에서 관리한다.

| 상태 | 의미 |
|---|---|
| clean | DB와 Markdown 동기화됨 |
| dirty | 파일 변경 감지, DB 반영 전 |
| user_modified | 사용자가 최근 수정 |
| ai_pending | AI 수정 요청 대기 |
| conflict | revision 충돌 발생 |
| trashed | 휴지통 이동 상태 |

### 9.3 충돌 처리 정책

| 상황 | 처리 |
|---|---|
| 유저가 먼저 수정 | 유저 수정본 우선 |
| AI가 오래된 revision 기준 저장 시도 | 직접 덮어쓰기 금지 |
| AI 수정 필요 | 새 문서 또는 새 revision 생성 |
| 충돌 발생 | conflict 상태 표시 |
| 해결 방식 | 사용자 선택: 유저본 유지 / AI본 새 문서 / 수동 병합 / 자동 병합 제안 |

---

## 10. Queue 설계

복잡도를 줄이기 위해 Phase 1에서는 큐를 3개로 제한한다.

| 큐 | 역할 |
|---|---|
| DatabaseWriteQueue | 모든 SQLite 쓰기 직렬화 |
| IndexingQueue | 문서 변경 후 인덱싱 처리 |
| LlmJobQueue | 요약/추출/분석 작업 처리 |

### 10.1 DatabaseWriteQueue

- SQLite 쓰기는 단일 writer queue를 통해 처리한다.
- WAL mode를 사용한다.
- 트랜잭션은 짧고 작게 유지한다.
- 사용자 직접 작업을 최우선으로 처리한다.

### 10.2 IndexingQueue

- 문서 변경 감지 후 즉시 전체 인덱싱하지 않는다.
- debounce를 적용한다.
- batch 처리를 사용한다.
- 대량 재인덱싱은 idle 상태 또는 수동 실행으로 처리한다.
- UI thread를 막지 않는다.

### 10.3 LlmJobQueue

- 요약, 태그 추천, 개인 후보 추출, 자연어 검색 변환을 처리한다.
- live 파일을 반복적으로 직접 읽지 않고 snapshot 또는 chunk 기준으로 처리한다.
- 외부 API 작업은 preflight 확인 후 실행한다.

---

## 11. 다수 AI 접속과 작업큐

### 11.1 기본 원칙

- 읽기 작업은 병렬 허용한다.
- 검색 작업은 병렬 허용한다.
- 쓰기/수정/삭제 작업은 ticket 기반 작업큐를 통해 순차 처리한다.
- 각 AI는 작업 요청 시 ticket을 발급받아야 한다.
- 수정/쓰기 권한은 capability token으로 제어한다.

### 11.2 Capability Token

SAC의 write / destructive / admin token은 capability 기반으로 관리한다.

| 속성 | 설명 |
|---|---|
| scope | tool + document + action 단위 |
| TTL | 짧은 만료 시간 |
| one-time | destructive 작업은 1회용 |
| hidden | token 값은 LLM 프롬프트에 노출하지 않음 |
| audit | 모든 write/destructive 작업 기록 |

중요 원칙:

> 토큰은 AI에게 텍스트로 넘기는 값이 아니라, SAC 내부 권한 시스템이 보유하고 검증하는 capability다.

---

## 12. 개인정보 보호

### 12.1 보호 원칙

- 개인 데이터는 기본적으로 로컬에서만 처리한다.
- 개인 아카이브 데이터는 Workspace 내부 SQLite에 저장된다.
- 외부 API로 개인 데이터가 자동 전송되지 않는다.
- 사용자가 외부 API 사용을 직접 활성화해야 한다.
- 외부 API 사용 시 전송 전 확인 절차를 거친다.
- 민감 정보 외부 전송은 기본 OFF이다.

### 12.2 외부 전송 preflight scanner

외부 API, 외부 TTS, 개인 아카이브 분석 API 호출 전 동일한 preflight 흐름을 사용한다.

```text
외부 전송 요청
→ preflight scanner
→ 민감 정보 후보 표시
→ redaction preview
→ 전송 범위 미리보기
→ 사용자 승인 / 취소
→ API 호출
→ audit log 저장
```

Phase 1에서는 preflight scanner를 최소 구현한다.

Phase 1 최소 구현:

- 외부 전송 대상 텍스트 표시
- 민감도 라벨 표시
- 사용자 확인
- audit log 기록

Phase 2 이후:

- 정교한 자동 redaction
- 민감 정보 패턴 탐지 고도화
- 카테고리별 자동 차단 규칙

---

## 13. TTS 정책

### 13.1 기본값

TTS 기본 엔진은 OS System TTS 또는 Local TTS다.

| TTS 유형 | 기본 정책 |
|---|---|
| OS System TTS | 기본값 |
| Local TTS | 허용 |
| External TTS API | 기본 OFF |
| 개인 아카이브 문서 | 외부 TTS 자동 차단 또는 확인 필요 |
| 민감 정보 포함 문서 | 외부 TTS 자동 차단 또는 redaction 후 확인 |

### 13.2 UX 원칙

- 매 문장마다 확인 팝업을 띄우지 않는다.
- 외부 TTS는 문서 또는 세션 단위로 확인한다.
- 로컬 TTS 사용 시 확인 팝업을 띄우지 않는다.
- 현재 읽는 문장 하이라이트를 제공한다.
- 속도 조절 0.5x~2.0x를 제공한다.

---

## 14. 테마 / 접근성 / 입력 밀도

### 14.1 테마

| 테마 | 설명 |
|---|---|
| Friendly Light | 기본 테마, 일반 유저 친화 |
| Dark | 일반적인 다크 모드 |
| High Contrast | 검정 + 노랑 중심 고대비 |
| Pink | 커스텀 프리셋 |
| Yellow | 커스텀 프리셋 |
| Blue | 커스텀 프리셋 |

### 14.2 입력 밀도

SAC는 컴포넌트 크기를 고정값으로 직접 지정하지 않고 density token을 사용한다.

| 모드 | 기준 |
|---|---|
| Compact | 32~36px |
| Comfortable | 40~44px |
| Accessibility | 50px 이상 |
| High Contrast | 50px 이상 |
| Touch Mode | 50px 이상 |

기본값은 Comfortable이다.

### 14.3 하단 고대비 토글

모든 주요 화면 하단 푸터에는 고대비 토글을 제공한다.

```text
[MCP 상태] [Workspace명] [sync 요약] [고대비 토글]
```

---

## 15. 다국어 설계

### 15.1 기본 언어

- 기본값: 한국어

### 15.2 지원 언어

| 언어 | 코드 |
|---|---|
| 한국어 | ko |
| 영어 | en |
| 중국어 | zh |
| 일본어 | ja |
| 베트남어 | vi |
| 스페인어 | es |
| 독일어 | de |
| 프랑스어 | fr |

### 15.3 Phase 1 정책

- i18n 구조는 Phase 1에서 준비한다.
- 한국어와 영어 리소스를 우선 안정화한다.
- 나머지 언어는 리소스 구조와 fallback 정책을 먼저 제공한다.
- 미번역 문구는 한국어 또는 영어 fallback을 따른다.
- 문서 원문은 자동 번역하지 않는다.
- AI 응답 언어와 앱 UI 언어는 별도 설정 가능해야 한다.

---

## 16. 시작 시 실행 옵션

### 16.1 기본값

- 시작 시 자동 실행: OFF

### 16.2 지원 OS

- Windows
- macOS

### 16.3 설정 항목

| 항목 | 기본값 | 설명 |
|---|---|---|
| launch_at_startup | false | OS 시작 시 SAC 자동 실행 |
| start_minimized | false | 백그라운드/최소화 상태 시작 |
| auto_start_mcp_server | false | 앱 시작 시 MCP 서버 자동 실행 |
| reopen_last_workspace | true | 마지막 Workspace 자동 열기 |
| open_dashboard_on_launch | true | 시작 시 대시보드 열기 |

MCP 자동 시작은 앱 자동 실행과 별도 옵션으로 둔다.

---

## 17. 화면 구성

### 17.1 기본 레이아웃

```text
좌측 사이드바 메뉴
        │
        ├─ 중앙 메인 화면
        │
        └─ 우측 컨텍스트 패널
```

### 17.2 좌측 메뉴

| 순서 | 메뉴 |
|---|---|
| 1 | 대시보드 |
| 2 | 문서 아카이브 |
| 3 | AI 협업 프로토콜 |
| 4 | 개인 아카이브 |
| 5 | 검색 |
| 6 | 휴지통 |
| 7 | 작업큐 / 티켓 |
| 8 | MCP / AI 도구 |
| 9 | 개인정보 보호 |
| 10 | 설정 |

### 17.3 메인 대시보드

```text
[1] AI 협업 프로토콜 현황
[2] Critical / 검증 / 충돌 알림
[3] 자연어 검색 바
[4] 개인 아카이브 바로가기
[5] 최근 문서 키워드 해시태그
[6] 최근 활동 / 최근 문서
[7] 작업큐 요약
[8] 개인정보 보호 상태 요약
```

---

## 18. SQLite 테이블 초안

| 테이블 | 역할 |
|---|---|
| workspaces | Workspace 정보 |
| documents | 문서 메타데이터 |
| document_chunks | 검색/요약/추출용 문서 조각 |
| document_fts | FTS5 전문 검색 |
| document_links | 문서 간 링크/참조 관계 |
| trash_items | 휴지통 복구용 정보 |
| sync_state | 파일 동기화 상태 |
| sync_journal_index | sync_journal 요약 인덱스 |
| ai_agents | 접속 AI 정보 |
| work_tickets | 작업 요청 티켓 |
| write_locks | 문서별 쓰기 잠금 |
| task_queue | 대기 중 작업 |
| task_results | 작업 결과 |
| permission_tokens | capability token 메타데이터 |
| personal_profile_manual | 고정 입력폼 기반 개인 프로필 |
| personal_memory_comments | 일지/코멘트형 사용자 직접 입력 |
| personal_archive_categories | 개인 아카이브 추출 카테고리 설정 |
| personal_extraction_queue | 자동 추출된 개인 데이터 승인 대기열 |
| personal_archive_items | 승인된 개인 아카이브 항목 |
| personal_timeline_events | 날짜별 개인 관련 타임라인 |
| personal_context_exports | LLM용 자기정보 추출문서 생성 기록 |
| personal_chat_sessions | 나에 대해 이야기하기/질문하기 세션 |
| personal_chat_messages | 개인 대화 메시지 |
| llm_jobs | 요약/추출/분석 작업 기록 |
| mcp_events | MCP tool 호출 기록 |
| audit_logs | 주요 작업 감사 로그 |
| app_settings | 앱 설정 |
| theme_settings | 테마 / 고대비 설정 |
| tts_settings | TTS 설정 |
| i18n_settings | 언어 설정 |

---

## 19. MCP Tools Phase 1

| Tool | 역할 |
|---|---|
| list_documents | 문서 목록 조회 |
| get_document | 특정 Markdown 문서 읽기 |
| create_document | 새 Markdown 문서 생성 |
| update_document | 기존 문서 수정 요청 |
| move_document_to_trash | 문서 휴지통 이동 요청 |
| restore_document_from_trash | 휴지통 문서 복구 |
| search_documents | 기본 FTS 검색 |
| natural_language_search | 자연어 검색 |
| get_document_tree | 폴더 기준 문서 트리 조회 |
| organize_document | 문서 요약/태그/분류 |
| extract_personal_archive_candidates | 개인 아카이브 후보 추출 |
| list_personal_extraction_queue | 개인 데이터 추출 대기열 조회 |
| generate_personal_context_export | LLM용 자기정보 문서 생성 |
| create_work_ticket | 작업 티켓 생성 |
| get_task_queue | 작업큐 조회 |
| request_write_capability | 쓰기 capability 요청 |
| get_settings | 설정 조회 |
| update_settings | 설정 수정 요청 |

Phase 1에서는 personal archive 후보의 자동 승인을 제공하지 않는다.

---

## 20. Phase 1 최소 구현 범위

Phase 1은 안전한 코어를 만드는 단계다.

### Phase 1에 반드시 포함

1. Flutter Desktop 앱 기본 구조
2. Friendly Light 기본 테마
3. Dark / High Contrast / Custom preset 구조
4. 하단 고대비 토글
5. Workspace 생성/선택
6. SQLite DB Workspace 내부 생성
7. Markdown 문서 CRUD
8. 최소 frontmatter 메타데이터
9. SQLite documents / sync_state
10. sync_journal append-only 기록
11. FTS5 기본 검색
12. 휴지통 이동/복구
13. DatabaseWriteQueue
14. IndexingQueue debounce/batch
15. LlmJobQueue 기본 구조
16. TypeScript MCP sidecar
17. MCP 기본 read/write tools
18. MCP tool on/off
19. capability token 기본 구조
20. AI 덮어쓰기 방지
21. 개인 아카이브 UI
22. 개인 데이터 추출 대기열
23. 모든 추출 후보 수동 승인
24. 개인정보 보호 메뉴
25. 외부 API preflight 최소 구현
26. OS/Local TTS 기본
27. 다국어 리소스 구조
28. 시작 시 실행 옵션
29. 매 스프린트 macOS smoke test

### Phase 1에서 제외하거나 최소화

| 항목 | Phase 1 처리 |
|---|---|
| sync_journal 기반 정밀 복구 | 기록만 구현, 복구 엔진은 Phase 2 |
| 개인 정보 자동 승인 | 금지, 전부 수동 승인 |
| 고급 민감도 탐지 | 라벨 보조 수준 |
| 자동 redaction | Phase 2 |
| 벡터 검색 | Phase 2 이후 |
| 8개국어 완성 번역 | 구조와 fallback 우선 |
| 외부 TTS 고급 연동 | 기본 OFF |
| Remote MCP | Phase 2 이후 |
| Cloud sync | Phase 2 이후 |

---

## 21. Done 기준

SAC Phase 1은 다음 조건을 만족하면 완료로 본다.

1. Windows에서 앱 실행 및 Workspace 생성 가능
2. macOS에서 smoke build/test 통과
3. Markdown 문서 CRUD 가능
4. SQLite 인덱싱 가능
5. FTS 검색 가능
6. 휴지통 이동/복구 가능
7. 기본 sync_state 관리 가능
8. AI가 사용자 수정본을 덮어쓰지 못함
9. TypeScript MCP sidecar 실행 가능
10. MCP tool on/off 가능
11. DatabaseWriteQueue / IndexingQueue / LlmJobQueue 기본 동작
12. 개인 데이터 후보가 대기열에 저장됨
13. 모든 개인 데이터 후보가 수동 승인됨
14. 외부 API 전송 전 확인 표시
15. 개인정보 보호 상태 화면 제공
16. Friendly Light / Dark / High Contrast 전환 가능
17. 하단 고대비 토글 동작
18. 시스템 또는 로컬 TTS 재생 가능
19. 설정에서 언어 구조 확인 가능
20. 설정에서 Windows/macOS 시작 시 실행 옵션 확인 가능

---

## 22. 최종 고정 판단

SAC Final Specification v1.0은 Phase 1 개발 기준으로 고정한다.

이후 새 분석에서 리스크가 발견되더라도, 다음 원칙을 따른다.

- Phase 1을 흔드는 구조 변경은 하지 않는다.
- 치명적 보안/데이터 손실 이슈만 즉시 반영한다.
- 나머지는 Phase 2 후보로 기록한다.
- 개발 중 발견된 문제는 작업지시문과 완료보고서에서 관리한다.

한 줄 결론:

> SAC Phase 1은 기능을 많이 만드는 단계가 아니라, 로컬 Markdown Workspace와 TypeScript MCP sidecar를 중심으로 안전한 AI 협업 아카이브 코어를 고정하는 단계다.

— 루미
