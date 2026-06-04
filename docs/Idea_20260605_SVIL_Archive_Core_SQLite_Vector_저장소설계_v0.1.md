---
title: "SVIL Archive Core SQLite + Vector 저장소 설계 v0.1"
author: "루미"
project: "SVIL Archive Core"
type: "기술설계"
status: "draft"
created: "2026-06-05"
updated: "2026-06-05"
tags:
  - SVIL
  - Archive-Core
  - SQLite
  - Vector-Search
  - FTS5
  - Local-First
  - Personal-Archive
---

# SVIL Archive Core SQLite + Vector 저장소 설계 v0.1 — 루미

작성일: 2026-06-05  
작성자: 루미

## 한 줄 정의

SVIL Archive Core는 Markdown 원본 파일을 유지하면서, SQLite를 로컬 인덱스 데이터베이스로 사용해 메타데이터, 검색, 벡터 검색, 타임라인, 개인 데이터 아카이브를 관리한다.

---

## 기본 원칙

Markdown 파일은 원본이다.

SQLite는 원본을 대체하지 않는다.

SQLite는 다음 역할을 맡는다.

- 문서 인덱스
- 메타데이터 저장
- 전문 검색
- 벡터 검색
- 문서 관계 저장
- 개인 데이터 아카이브 저장
- 타임라인 관리
- AI 컨텍스트 패킷 생성
- 동기화 상태 관리

즉, 원본은 사람이 읽기 쉬운 Markdown으로 남기고, SQLite는 AI와 앱이 빠르게 찾고 분석하기 위한 로컬 두뇌 역할을 한다.

---

## 저장 구조 개념

```text
Markdown Files
  ↓ index / parse / embed
SQLite DB
  ├─ documents
  ├─ document_chunks
  ├─ document_fts
  ├─ document_vectors
  ├─ document_links
  ├─ personal_profile
  ├─ personal_trends
  ├─ timelines
  └─ sync_state
```

---

## 왜 SQLite인가

SQLite는 로컬 앱에 적합하다.

장점:

- 별도 서버가 필요 없음
- 단일 파일로 백업 가능
- GitHub / Drive 백업과 궁합 좋음
- 로컬 우선 구조에 적합
- 개인 데이터 저장에 적합
- FTS5로 전문 검색 가능
- 확장을 통해 벡터 검색 가능

---

## 핵심 저장 대상

### 1. documents

Markdown 문서 하나를 대표하는 테이블.

저장 정보:

- 문서 ID
- 파일 경로
- 제목
- 작성자
- 문서 타입
- 프로젝트
- 상태
- 생성일
- 수정일
- 태그
- 요약
- 해시값
- 동기화 상태

예상 스키마:

```sql
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  path TEXT NOT NULL UNIQUE,
  title TEXT,
  author TEXT,
  project TEXT,
  type TEXT,
  status TEXT,
  created_at TEXT,
  updated_at TEXT,
  summary TEXT,
  hash TEXT,
  metadata_json TEXT
);
```

---

### 2. document_chunks

긴 문서를 검색과 임베딩 단위로 쪼갠 테이블.

저장 정보:

- chunk ID
- 문서 ID
- chunk 순서
- 본문 일부
- 헤딩 경로
- 토큰 수
- 생성일

예상 스키마:

```sql
CREATE TABLE document_chunks (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  chunk_index INTEGER NOT NULL,
  heading_path TEXT,
  content TEXT NOT NULL,
  token_count INTEGER,
  created_at TEXT,
  FOREIGN KEY(document_id) REFERENCES documents(id)
);
```

---

### 3. document_fts

전문 검색용 FTS5 테이블.

검색 대상:

- 제목
- 요약
- 본문 chunk
- 태그
- 프로젝트
- 문서 타입

예상 스키마:

```sql
CREATE VIRTUAL TABLE document_fts USING fts5(
  title,
  summary,
  content,
  tags,
  project,
  type,
  content='',
  tokenize='unicode61'
);
```

---

### 4. document_vectors

벡터 검색용 테이블.

저장 정보:

- chunk ID
- embedding 모델명
- embedding 벡터
- 생성일
- 업데이트일

구현은 sqlite-vec 같은 SQLite 벡터 확장을 활용할 수 있다.

개념 스키마:

```sql
CREATE VIRTUAL TABLE document_vectors USING vec0(
  chunk_id TEXT PRIMARY KEY,
  embedding FLOAT[768]
);
```

주의:

실제 스키마는 선택하는 벡터 확장에 따라 달라질 수 있다.

---

### 5. document_links

문서 간 연결 관계.

예시:

- 작업지시문 → 완료보고서
- 완료보고서 → 검증보고서
- 루미의 일기 → 참고 문서
- 프로젝트 문서 → 관련 아이디어
- Archive Core 기획 → 개인 데이터 아카이브 모듈

예상 스키마:

```sql
CREATE TABLE document_links (
  id TEXT PRIMARY KEY,
  source_document_id TEXT NOT NULL,
  target_document_id TEXT NOT NULL,
  relation_type TEXT,
  note TEXT,
  created_at TEXT
);
```

---

## 개인 데이터 아카이브 저장

개인 데이터 아카이브도 SQLite에 저장한다.

단, 원본 문서와 추출 데이터를 분리한다.

### personal_profile

사용자에 대한 장기 프로필.

```sql
CREATE TABLE personal_profile (
  id TEXT PRIMARY KEY,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  source_document_id TEXT,
  confidence REAL,
  updated_at TEXT
);
```

예시 key:

- preferred_call
- current_interest
- core_value
- avoided_pattern
- response_preference
- active_project
- paused_project

---

### personal_trends

기간별 관심사 변화.

```sql
CREATE TABLE personal_trends (
  id TEXT PRIMARY KEY,
  period_start TEXT,
  period_end TEXT,
  topic TEXT,
  weight REAL,
  trend_direction TEXT,
  summary TEXT,
  source_json TEXT
);
```

trend_direction 예시:

- increasing
- decreasing
- stable
- paused
- resurfacing

---

### timelines

사용자의 생각과 프로젝트 흐름을 시간순으로 저장한다.

```sql
CREATE TABLE timelines (
  id TEXT PRIMARY KEY,
  event_date TEXT,
  event_type TEXT,
  title TEXT,
  summary TEXT,
  source_document_id TEXT,
  project TEXT,
  tags TEXT
);
```

---

## 검색 방식

SVIL Archive Core의 검색은 세 가지를 섞는다.

### 1. 트리 검색

사람이 직접 폴더 구조로 찾는 방식.

장점:

- 직관적
- 사용자가 통제 가능
- 프로젝트 구조 이해에 좋음

### 2. 전문 검색

FTS5 기반 키워드 검색.

장점:

- 정확한 단어 검색
- 제목 / 본문 / 태그 검색
- 빠른 검색
- 작업지시문, 보고서, 이름 검색에 좋음

### 3. 벡터 검색

의미 기반 검색.

장점:

- 표현이 달라도 비슷한 문서 찾기 가능
- 중단된 아이디어 찾기
- 관련 문서 추천
- AI 컨텍스트 생성에 좋음

---

## 하이브리드 검색

가장 좋은 방식은 전문 검색과 벡터 검색을 섞는 것이다.

예시:

```text
검색어: "노션 대체 문서 저장소"

FTS 결과:
- Notion 블록 제한
- Markdown 저장소
- GitHub 백업

Vector 결과:
- SVIL Archive Core
- 개인 데이터 아카이브
- AI 친화적 문서 프로토콜
```

최종 결과는 두 검색 결과를 합쳐 정렬한다.

정렬 기준 후보:

- 키워드 일치도
- 벡터 유사도
- 최근 수정일
- 문서 중요도
- 프로젝트 우선순위
- 사용자가 자주 연 문서
- 현재 작업 컨텍스트

---

## 파일과 SQLite의 관계

Markdown 파일이 원본이다.

SQLite는 언제든 재생성 가능해야 한다.

즉, SQLite가 손상되어도 Markdown 폴더를 다시 스캔해 인덱스를 복구할 수 있어야 한다.

원칙:

```text
Markdown = Source of Truth
SQLite = Index / Memory / Search Brain
Cloud = Backup / Sync
```

---

## 백업 방식

백업 대상:

- Markdown 원본 폴더
- SQLite DB 파일
- 설정 파일
- 임베딩 모델 정보
- 동기화 로그

백업 위치:

- GitHub
- Google Drive
- OneDrive
- 로컬 외장 드라이브
- Railway 백엔드 옵션

주의:

SQLite DB는 백업 중 잠금 문제가 생길 수 있으므로, 직접 복사보다 백업용 snapshot 생성이 안전하다.

---

## 로컬 AI와의 관계

로컬 LLM / Ollama는 다음 작업을 수행한다.

- Markdown 문서 요약
- 문서 타입 분류
- 태그 추천
- 관련 문서 추천
- 개인 관심사 추출
- 타임라인 이벤트 생성
- AI 컨텍스트 패킷 생성

DeepSeek API 같은 외부 API는 선택적으로 사용한다.

외부 API 사용 후보:

- 긴 문서 요약
- 복잡한 관계 분석
- 대량 문서 재분류
- 월간 트렌드 리포트
- 고품질 context packet 생성

---

## MVP 구현 순서

### Phase 1. SQLite 문서 인덱스

- 로컬 폴더 스캔
- Markdown 메타데이터 파싱
- documents 테이블 생성
- document_chunks 생성
- 파일 변경 감지

### Phase 2. 전문 검색

- FTS5 인덱스 생성
- 제목 / 본문 / 태그 검색
- 검색 결과 하이라이트
- 문서 타입 필터

### Phase 3. 벡터 검색

- chunk 임베딩 생성
- document_vectors 저장
- 유사 문서 검색
- 관련 문서 추천

### Phase 4. 개인 데이터 아카이브

- 최근 관심사 추출
- 중단된 아이디어 추적
- 타임라인 생성
- AI context packet 생성

### Phase 5. MCP 서버

- search_documents
- get_document
- list_related_documents
- get_personal_context
- get_timeline
- suggest_context_packet

---

## 루미 판단

SQLite는 SVIL Archive Core의 중심 저장소로 적합하다.

다만 SQLite가 원본이 되면 안 된다.

원본은 Markdown 파일이고, SQLite는 검색과 분석을 위한 두뇌여야 한다.

이 구조가 좋은 이유는 명확하다.

- 데이터 소유권은 Markdown이 지킨다.
- 검색 성능은 SQLite가 담당한다.
- 의미 검색은 벡터 인덱스가 담당한다.
- AI 활용은 MCP와 context packet이 담당한다.
- 백업은 GitHub / Drive가 담당한다.

한 줄로 정리하면:

> Markdown은 기억의 원본이고, SQLite는 기억을 찾는 두뇌다.

— 루미
