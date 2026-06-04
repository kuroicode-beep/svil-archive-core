---
title: "SVIL Archive Core 핵심 컨셉 v0.1"
author: "루미"
project: "SVIL"
type: "기획초안"
status: "draft"
created: "2026-06-05"
updated: "2026-06-05"
tags:
  - SVIL
  - Archive
  - Markdown
  - MCP
  - AI-Friendly
  - Knowledge-Archive
---

# SVIL Archive Core 핵심 컨셉 v0.1 — 루미

작성일: 2026-06-05  
작성자: 루미

## 한 줄 정의

SVIL Archive Core는 AI와 사람이 함께 사용하는 Markdown 기반 문서 아카이브 앱이다.

목표는 예쁜 Markdown 에디터를 만드는 것이 아니라, AI가 읽고 찾고 연결하고 인계받기 쉬운 문서 운영 시스템을 만드는 것이다.

---

## 주요 컨셉

### 1. AI 통신 프로토콜 MCP

SVIL Archive Core의 가장 중요한 차별점은 MCP 기반 AI 통신 프로토콜이다.

앱이 단순히 AI 기능을 내장하는 것이 아니라, 여러 AI가 공통으로 접속할 수 있는 문서 서버 역할을 한다.

예상 MCP 기능:

- 문서 검색
- 문서 읽기
- 문서 생성
- 문서 수정 제안
- 프로젝트별 문서 목록 조회
- 검증 대기 문서 조회
- 관련 문서 추천
- 루미의 일기 작성 / 조회

초기 원칙:

- 기본은 읽기 전용
- 쓰기 작업은 사용자 승인 필요
- AI별 권한 분리
- 작업 로그 기록

---

### 2. Markdown 문서 관리

이 앱은 Markdown 에디터가 아니라 Markdown 문서 관리 앱이다.

편집 기능은 기본만 제공한다.

핵심은 문서를 잘 만들고, 분류하고, 찾고, 연결하는 것이다.

주요 기능:

- 폴더 기반 문서 관리
- Markdown 파일 생성 / 이동 / 이름 변경
- YAML 메타데이터 관리
- 문서 타입 지정
- 프로젝트 연결
- 작성자 표시
- 상태 관리
- 관련 문서 연결

문서 예시:

- 작업지시문
- 완료보고서
- 검증보고서
- 설계분석보고서
- 루미의 일기
- 운영 원칙
- 콘텐츠 기획서

---

### 3. 로컬 AI 활용 자동화

SVIL Archive Core는 로컬 AI를 활용해 반복 작업을 자동화한다.

기본 방향:

- 로컬 LLM / Ollama 중심
- 비용 발생이 큰 작업은 최소화
- 필요한 경우 DeepSeek 등 외부 API 연결 가능

자동화 후보:

- 문서 요약
- 문서 타입 자동 분류
- 태그 추천
- 관련 문서 추천
- 오래된 문서 정리 후보 표시
- 중복 문서 감지
- 작업지시문 / 완료보고서 / 검증보고서 구조 점검
- 루미의 일기 참고 문서 자동 추천

---

### 4. 친숙한 트리 구조와 벡터 검색

기본 탐색 방식은 친숙한 트리 구조이다.

사용자는 파일과 폴더를 직접 이해할 수 있어야 한다.

동시에 벡터 검색을 제공해 의미 기반 탐색을 가능하게 한다.

기본 탐색:

- 폴더 트리
- 프로젝트별 보기
- 문서 타입별 보기
- 상태별 보기
- 작성자별 보기
- 태그별 보기

고급 검색:

- 전문 검색
- 벡터 검색
- 비슷한 문서 찾기
- 관련 문서 묶음 보기
- 작업 흐름 추적

예시 흐름:

```text
작업지시문 → 완료보고서 → 검증보고서 → 수정보고서 → 최종보고서
```

---

### 5. 안전한 데이터 백업과 무료 클라우드 이용

데이터는 사용자가 소유해야 한다.

원본은 로컬 Markdown 파일 또는 GitHub 저장소에 둔다.

클라우드는 백업과 공유용으로 사용한다.

역할 분리:

- 로컬 폴더: 실제 작업본
- GitHub: 원본 저장소 / 버전관리
- Google Drive: 백업 / AI 공유 접근
- OneDrive: 선택 백업
- Railway backend: 선택 기능

기본 원칙:

- 특정 플랫폼에 종속되지 않는다.
- Markdown 원본은 항상 사용자가 접근 가능해야 한다.
- 클라우드 백업은 선택 기능이다.
- 무료 클라우드 사용을 우선한다.

---

### 6. 기본 로컬 앱 + Railway 백엔드 옵션

초기 형태는 로컬 앱이다.

로컬 앱은 사용자의 문서 폴더를 직접 관리한다.

Railway 백엔드는 선택 기능으로 둔다.

로컬 앱 담당:

- 문서 편집
- 문서 관리
- 검색
- 로컬 AI 자동화
- GitHub 연동
- 클라우드 백업

Railway 백엔드 옵션:

- 원격 인덱스
- 여러 기기 동기화 보조
- 웹 대시보드
- 외부 AI 접근용 API
- 예약 백업
- 뉴스레터 / 운영 리포트 생성

주의:

Railway 백엔드는 필수 의존성이 되어서는 안 된다.

기본 앱은 백엔드 없이도 작동해야 한다.

---

## 포지션

SVIL Archive Core는 Notion 대체품이 아니다.

Obsidian 대체품도 아니다.

정확한 포지션은 AI 친화적 Markdown 아카이브이다.

사람이 읽기 좋은 노트앱보다, AI가 맥락을 잃지 않게 해주는 문서 저장소에 가깝다.

```text
Notion 대체품 ❌
Obsidian 대체품 ❌
AI 친화적 Markdown 아카이브 ⭕
```

---

## 핵심 가치

- 문서 원본을 사용자가 소유한다.
- AI가 같은 문서 구조를 읽고 쓸 수 있다.
- Markdown 기반이라 장기 보존이 쉽다.
- GitHub와 궁합이 좋다.
- 무료 클라우드를 백업으로 활용할 수 있다.
- Notion의 블록 제한과 락인을 피할 수 있다.
- SVIL의 작업지시문 / 완료보고서 / 검증보고서 흐름에 최적화할 수 있다.

---

## 초기 MVP 후보

1. 로컬 폴더 선택
2. Markdown 문서 트리 표시
3. 기본 편집
4. YAML 메타데이터 폼
5. 문서 타입 템플릿
6. 전문 검색
7. 벡터 검색
8. 관련 문서 수동 / 자동 연결
9. GitHub commit / push
10. Google Drive / OneDrive 백업
11. 읽기 전용 MCP 서버
12. 쓰기 작업 승인 흐름

---

## 예상 폴더 구조

```text
SVIL_Archive/
  00_Index/
    index.md
    ai-routing.md

  01_Rulebook/
    svil-ai-collaboration-guide.md
    agent-roles.md
    notion-agent-protocol.md

  02_Projects/
    Tether/
      project-brief.md
      work-orders/
      completion-reports/
      verification-reports/

  03_Content/
    Blog/
    YouTube/

  04_Lumi_Diary/
    2026/
      2026-06-04_lumi-diary-001.md

  05_OpenClaw/
    operations-design.md
    daily-reports/

  06_Archive_Core/
    concept.md
    mvp.md
    architecture.md

  99_Archive/
```

---

## 기본 문서 메타데이터 예시

```yaml
---
title: "OpenClaw 운영실 설계서 v1.0"
author: "루미"
project: "SVIL"
type: "운영설계서"
status: "active"
created: "2026-06-05"
updated: "2026-06-05"
next_ai: "Cursor"
related:
  - "SVIL Agent 역할 정의서 v1.0"
  - "SVIL H2 2026 선언문"
drive_sync: true
github_path: "05_OpenClaw/operations-design.md"
---
```

---

## 루미 메모

이 아이디어는 단순히 Notion이 불편해서 나온 대체안이 아니다.

Notion을 쓰면서 발견한 진짜 문제는 문서 비용이 아니라, AI 시대의 문서 운영 방식이 아직 충분히 정리되지 않았다는 점이다.

SVIL Archive Core는 문서를 예쁘게 보관하는 앱이 아니라, AI가 기억을 잃지 않고 작업을 이어가게 만드는 기반 시스템이 될 수 있다.

처음부터 크게 만들면 위험하다.

하지만 SVIL 내부 도구로 작게 시작하면, 나중에는 외부 공개까지도 생각해볼 만한 방향이다.

한 줄로 남기면:

> 사람이 쓰기 좋은 노트앱이 아니라, AI와 사람이 함께 쓰는 기억 프로토콜을 만든다.

— 루미
