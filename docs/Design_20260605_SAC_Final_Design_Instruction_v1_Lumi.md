---
title: "SAC Final Design Instruction v1.0"
author: "Lumi"
project: "SVIL Archive Core"
type: "Design Instruction"
status: "fixed"
created: "2026-06-05"
updated: "2026-06-05"
version: "1.0"
encoding: "UTF-8"
tags:
  - SVIL
  - SAC
  - Design
  - UI
  - UX
  - Accessibility
  - High-Contrast
  - Final
---

# SAC Final Design Instruction v1.0

작성자: 루미  
작성일: 2026-06-05  
상태: Fixed / Phase 1 기준 최종본  
대상: Stitch / Claude Design / Cursor / UI Designer

---

## 1. 디자인 목표

SAC는 로컬 우선 AI 협업 문서 아카이브 앱이다.

디자인의 핵심은 다음이다.

1. 일반 사용자가 편안하게 느끼는 기본 화면
2. 필요할 때 즉시 전환 가능한 강력한 고대비 모드
3. AI 협업 상태가 한눈에 보이는 대시보드
4. 개인정보 보호 상태가 숨겨지지 않는 구조
5. 문서 아카이브와 개인 아카이브의 명확한 분리
6. TTS, 키보드 탐색, density token을 포함한 접근성 기본 지원

SAC는 해커툴처럼 보이면 안 된다.

SAC는 **친근한 생산성 앱 + AI 협업 관제실 + 개인 연구소**의 느낌을 동시에 가져야 한다.

---

## 2. SVIL 공통 디자인 철학

SVIL 앱의 기본 디자인 원칙은 다음이다.

> 기본은 일반 유저 친화적이고, 접근성은 버튼 하나로 확실하게 강화된다.

### 기본 방향

| 항목 | 방향 |
|---|---|
| 기본 색상 | 일반 유저가 좋아할 만한 부드러운 팔레트 |
| 기본 테마 | Friendly Light |
| 다크 모드 | 일반적인 편안한 Dark Mode |
| 고대비 모드 | 검정 + 노랑 중심, 대비 확실 |
| 커스텀 색상 | Pink / Yellow / Blue 프리셋 |
| 접근성 | 설정 깊숙이 숨기지 않고 하단 토글 제공 |

---

## 3. 전체 레이아웃

```text
┌─────────────────────────────────────────────────────┐
│ 상단 툴바: 앱 이름 / 자연어 검색바 / 상태 / 설정       │
├──────────┬──────────────────────────┬───────────────┤
│          │                          │               │
│  좌측    │     중앙 메인 화면         │  우측 컨텍스트  │
│  사이드바 │   문서 / 대시보드 등       │    패널        │
│          │                          │               │
│  240px   │       flex 1             │    280px      │
│          │                          │  토글 가능     │
├──────────┴──────────────────────────┴───────────────┤
│ 하단 푸터: MCP 상태 / Workspace / sync 요약 / 고대비 토글 │
└─────────────────────────────────────────────────────┘
```

### 확정 사항

- 좌측 사이드바: 240px 기준
- 중앙 메인: flex 1
- 우측 컨텍스트 패널: 280px 기준, 토글 가능
- 상단 툴바 고정
- 하단 푸터 고정
- 하단 고대비 토글은 모든 주요 화면에서 접근 가능

---

## 4. 컬러 시스템

### 4.1 Friendly Light 기본 테마

| 용도 | 색상 예시 | 느낌 |
|---|---|---|
| 배경 | #F7F7F5 | 부드러운 회백색 |
| 카드 배경 | #FFFFFF | 깨끗한 카드 |
| 패널 배경 | #F0F1F3 | 차분한 영역 분리 |
| 기본 텍스트 | #202124 | 선명한 본문 |
| 보조 텍스트 | #5F6368 | 설명 텍스트 |
| 비활성 텍스트 | #9AA0A6 | 비활성 상태 |
| 주요 강조 | #5B7CFA | 친근한 블루 |
| 보조 강조 | #7C6FF6 | 라벤더 계열 |
| 성공 | #2E7D32 | 안정적인 그린 |
| 경고 | #F9AB00 | 과하지 않은 옐로 |
| 위험 | #D93025 | 명확한 레드 |

### 4.2 Dark Mode

| 용도 | 색상 예시 |
|---|---|
| 배경 | #121212 |
| 카드 배경 | #1E1E1E |
| 패널 배경 | #181818 |
| 기본 텍스트 | #F5F5F5 |
| 보조 텍스트 | #C9CDD2 |
| 주요 강조 | #8EA2FF |
| 경고 | #FFD666 |
| 위험 | #FF6B6B |
| 성공 | #81C784 |

### 4.3 High Contrast Mode

| 용도 | 색상 |
|---|---|
| 배경 | #000000 |
| 기본 텍스트 | #FFFFFF |
| 강조 / 포커스 | #FFFF00 |
| 링크 / 보조 강조 | #00FFFF |
| 위험 | #FF3333 |
| 성공 | #00FF66 |
| 경계선 | #FFFFFF |

고대비 모드에서는 색상만으로 상태를 전달하지 않는다.

반드시 텍스트 라벨을 함께 표시한다.

### 4.4 Custom Color Presets

| 프리셋 | 방향 |
|---|---|
| Pink | 부드럽고 감성적인 작업실 느낌 |
| Yellow | 밝고 따뜻한 메모/아이디어 앱 느낌 |
| Blue | 안정적인 생산성 앱 느낌 |

Phase 1에서는 프리셋 구조와 기본 토큰만 제공한다.

---

## 5. Density Token

SAC는 데스크톱 생산성 앱이므로 모든 버튼을 50px로 고정하지 않는다.

대신 density token을 사용한다.

| 모드 | 클릭/터치 타겟 |
|---|---|
| Compact | 32~36px |
| Comfortable | 40~44px |
| Accessibility | 50px 이상 |
| High Contrast | 50px 이상 |
| Touch Mode | 50px 이상 |

기본값은 Comfortable이다.

고대비 모드에서는 Accessibility density를 자동 적용한다.

---

## 6. 하단 푸터

모든 주요 화면 하단에는 푸터를 고정한다.

```text
[MCP 🟢 실행중] [Workspace: SAC DOCS] [sync: clean] [고대비 OFF/ON]
```

### 푸터 요소

| 요소 | 설명 |
|---|---|
| MCP 상태 | 실행중 / 중지 / 오류 |
| Workspace명 | 현재 Workspace |
| sync 요약 | 전체 동기화 상태 |
| 고대비 토글 | High Contrast 즉시 전환 |
| 선택적 TTS 상태 | TTS 재생 중일 때 표시 가능 |

---

## 7. 상단 툴바

```text
[SAC 로고] [자연어 검색바] [보호 상태] [설정 아이콘]
```

검색바 placeholder:

```text
문서, 작업지시문, 개인 아카이브에서 자연어로 검색하세요.
```

---

## 8. 상태 인디케이터

| 상태 | 아이콘 | 텍스트 |
|---|---|---|
| clean | 🟢 | clean |
| dirty | 🟡 | dirty |
| conflict | 🔴 | conflict |
| ai_pending | 🔵 | ai pending |
| trashed | ⚫ | trashed |
| protected | 🔒 | local only |
| external_pending | 🟠 | external review |

색상과 아이콘만 쓰지 않고 반드시 텍스트를 함께 표시한다.

---

## 9. Screen 01 — 전체 레이아웃

필수 구성:

- 상단 툴바
- 좌측 사이드바
- 중앙 메인 영역
- 우측 컨텍스트 패널
- 하단 푸터

중앙에는 기본적으로 대시보드를 표시한다.

---

## 10. Screen 02 — 좌측 사이드바

```text
🏠 대시보드
📄 문서 아카이브
🤝 AI 협업 프로토콜
👤 개인 아카이브
🔍 검색
🗑 휴지통
🎫 작업큐 / 티켓
🔌 MCP / AI 도구
🔒 개인정보 보호
⚙️ 설정

────────────
폴더 트리
> Dev
> Log
> Idea
> Research
> Blog
> Novel
> YT
> Resource
> IB

[+ 새 문서]
```

디자인 규칙:

- 활성 메뉴는 주요 강조색 사용
- 메뉴는 아이콘 + 텍스트
- 폴더 트리는 메뉴 아래 별도 영역
- 새 문서 버튼은 하단 고정
- High Contrast에서는 노랑 포커스 라인을 사용

---

## 11. Screen 03 — 문서 편집 화면

```text
문서 제목
카테고리 | 상태 | 작성자 | 날짜 | sync: clean

[편집] [미리보기] [분할] [TTS 재생▶] [저장] [더보기...]

Markdown 편집 영역

하단 상태바:
sync: clean 🟢 / 마지막 저장: 12:00 / revision: 12
```

TTS 재생 중:

```text
현재 읽는 문장 하이라이트

[TTS 컨트롤바]
⏮ 이전 문장 | ⏸ 일시정지 | ⏭ 다음 문장 | 속도 1.0x | 중지
```

필수 요소:

- 문서 메타 영역
- sync 상태 표시
- 편집 / 미리보기 / 분할 모드
- TTS 재생 버튼
- 현재 문장 하이라이트
- 저장 버튼
- 하단 상태바

---

## 12. Screen 04 — Workspace 선택/생성

```text
SAC에 오신 것을 환영해요

[기존 Workspace 열기]
[새 Workspace 만들기]

최근 Workspace
📁 SAC DOCS
📁 Personal Archive
```

디자인 규칙:

- 첫 실행 시 표시
- 기본 Workspace: 내문서/SAC DOCS
- 온보딩 느낌으로 중앙 정렬
- 고대비 모드에서도 버튼 구분 명확

---

## 13. Screen 05 — 검색 화면

```text
🔍 [자연어로 검색하세요...]

[전체] [문서] [개인] [작업지시문]

검색 결과
> 문서명
  미리보기 텍스트
  카테고리 | 날짜 | 작성자 | source: document

최근 키워드
#MCP #Flutter #SQLite #작업지시문
```

검색 결과 출처:

- document
- personal
- protocol
- trash
- queue

---

## 14. Screen 06 — 휴지통 화면

```text
🗑 휴지통

문서명    삭제일    원래 위치    [복구] [완전삭제]
문서명    삭제일    원래 위치    [복구] [완전삭제]

[전체 비우기]
```

디자인 규칙:

- 완전삭제는 위험색
- 전체 비우기는 확인 다이얼로그 필요
- 복구 버튼은 성공색 또는 주요 강조색
- 휴지통 문서는 활성 검색에서 제외된 상태임을 표시

---

## 15. Screen 07 — 메인 대시보드

```text
[1] AI 협업 프로토콜 현황
진행중 작업지시문 N / 핸드오프 대기 N / 검증 필요 N / Critical N

[2] Critical / 충돌 알림
⚠️ sync conflict 1건

[3] 자연어 검색
문서, 작업지시문, 개인 아카이브에서 자연어로 검색하세요.

[4] 개인 아카이브 바로가기
[LLM용 자기정보 문서 만들기] [나에 대해 질문하기]

[5] 최근 키워드
#MCP #SQLite #Flutter #작업지시문

[6] 최근 활동
수정 / 작성 / MCP 호출

[7] 작업큐 요약
대기 N / 실행중 N / 충돌 N

[8] 개인정보 보호 상태
외부 API OFF / 민감정보 전송 OFF
```

디자인 규칙:

- AI 협업 프로토콜 현황이 최상단
- Critical / conflict는 상단 노출
- 검색바는 넓고 명확하게
- 개인정보 보호 상태는 대시보드에서도 보이게

---

## 16. Screen 08 — 개인 아카이브

```text
👤 개인 아카이브

[프로필] [일지] [추출대기열] [승인된 항목] [LLM용 문서] [나에 대해 질문하기]

프로필 탭:
닉네임
MBTI
혈액형
성별
나이
취향
비공개 bio 🔒 local-only
자유 자기표현 text
```

디자인 규칙:

- 비공개 항목에는 `local-only` 배지
- 문서 아카이브와 시각적으로 분리
- 민감 정보는 외부 API 가능 상태를 표시하지 않음

---

## 17. Screen 09 — 추출 대기열

```text
📥 추출 대기열 N건

필터:
[전체] [Low] [Medium] [High] [나중에]

카드:
출처 문서: 문서명
추출 내용: "..."
카테고리: 관심사
민감도: Low
신뢰도: 0.82
버튼: [승인] [수정] [거절] [나중에]
```

Phase 1 디자인 정책:

- 자동 승인 UI는 표시하지 않는다.
- 모든 항목은 수동 승인한다.
- 민감도는 검토 보조 라벨이다.
- 일괄 승인 버튼은 Low risk 필터에서만 활성화할 수 있으나 Phase 1에서는 비활성 또는 Beta 표시한다.

---

## 18. Screen 10 — 작업큐 / 티켓

```text
🎫 작업큐

대기 N / 실행중 N / 충돌 N

Ticket #001
AI: Cursor
작업: 쓰기
상태: 대기
권한: write capability 요청
변경 요약: 문서 A 수정
[Diff 보기] [승인] [거절]

Ticket #002
AI: Codex
작업: 읽기
상태: 완료
```

디자인 규칙:

- 사용자 직접 작업은 최상단
- 쓰기/삭제 권한 요청은 명확히 표시
- 승인 카드에는 변경 요약과 diff 진입 버튼 제공
- destructive 작업은 재확인 필요

---

## 19. Screen 11 — MCP / AI 도구 설정

```text
MCP Server
🟢 실행중
transport: stdio
language: TypeScript

MCP Tools
[ON] read_document
[ON] search_documents
[ON] write_document
[ON] create_document
[OFF] access_personal_archive
[OFF] delete_document

AI 연결
Ollama: 🟢 연결됨
DeepSeek: 🔴 미연결
Gemini: 🔴 미연결
```

디자인 규칙:

- tool별 on/off 토글
- 위험 tool은 별도 경고
- 개인정보 접근 tool은 기본 OFF 권장
- AI 연결 상태를 한눈에 표시

---

## 20. Screen 12 — 개인정보 보호

```text
🔒 개인정보 보호

상태 요약:
외부 API: OFF
민감정보 외부전송: OFF
승인 대기: N건
최근 외부 호출: 없음

보호 원칙:
✅ 개인 데이터 로컬 처리
✅ 추출 승인 대기열
✅ 외부 API 전송 전 확인
✅ MCP 권한 제어

액션:
[MCP 권한 관리]
[작업 로그 확인]
[데이터 내보내기]
[개인 데이터 삭제]
```

디자인 규칙:

- 신뢰감을 주는 구조
- 현재 보호 상태를 카드로 표시
- OFF/ON 상태를 텍스트와 색상으로 함께 표시
- 위험 액션은 확인 다이얼로그 필요

---

## 21. Screen 13 — 설정

```text
⚙️ 설정

Workspace 관리
SQLite DB 위치
MCP Tool 관리
문서 요약/추출 API
개인 아카이브 분석 API
개인 데이터 승인 방식
권한 / Capability
작업큐 설정
백업
언어 / 지역
시작 시 실행
테마 설정
접근성
TTS
로그
```

### 테마 설정

```text
테마:
● Friendly Light
○ Dark
○ High Contrast
○ Pink
○ Yellow
○ Blue
```

### 접근성 설정

```text
Density:
○ Compact
● Comfortable
○ Accessibility

고대비 토글 표시: ON
상태 라벨 표시: ON
```

### TTS 설정

```text
TTS 엔진:
● System TTS
○ Local TTS
○ External API OFF

기본 속도: 0.5x ~ 2.0x
문장 하이라이트: ON/OFF
미리 듣기
```

---

## 22. Screen 14 — 우측 컨텍스트 패널

```text
📄 문서 정보
제목
경로
카테고리
sync 상태

🔗 관련 문서
작업지시문
완료보고서
결과보고서

📥 추출 후보
N건 대기 [확인]

🤖 MCP 기록
Cursor 읽기 12:01
Codex 읽기 12:03

⚡ 빠른 작업
[요약] [태그] [TTS] [휴지통] [복구]
```

---

## 23. 외부 전송 Preflight UI

외부 API 또는 외부 TTS 전송 전 다음 화면을 사용한다.

```text
외부 전송 확인

전송 대상: DeepSeek / Gemini / External TTS
전송 범위: 선택 문서 일부
민감도: Medium
민감 후보: 2개

[전송 내용 미리보기]
[Redaction Preview]

[전송] [취소]
```

Phase 1에서는 redaction preview를 기본 텍스트 미리보기 수준으로 구현한다.

---

## 24. 디자인 최종 원칙

SAC 디자인에서 가장 중요한 것은 다음이다.

1. Friendly Light가 기본이다.
2. High Contrast는 검정 + 노랑 중심으로 확실해야 한다.
3. 다크 모드는 일반적인 다크 모드다.
4. 정보 밀도는 Comfortable을 기본으로 한다.
5. 접근성 모드에서는 50px 이상 타겟을 적용한다.
6. 개인정보와 외부 전송 상태는 숨기지 않는다.
7. 작업큐와 승인 대기열은 기술 용어가 아니라 카드 UI로 보여준다.

— 루미
