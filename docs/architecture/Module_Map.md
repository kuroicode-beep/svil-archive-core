---
title: "SAC Module Map"
author: "Claude Code (Sonnet)"
project: "SAC"
type: "모듈맵"
status: "draft"
created: "2026-06-05"
---

# SAC Module Map — Phase 1 Skeleton

---

## 폴더 구조

```
project_root/
├── app/
│   └── flutter_app/              Flutter Desktop 앱
│       └── lib/
│           ├── domain/
│           │   ├── models/       도메인 모델 (Dart)
│           │   └── services/     서비스 인터페이스 (abstract)
│           ├── data/
│           │   ├── db/           SQLite 구현체 (Cursor 구현)
│           │   └── file/         파일시스템 구현체 (Cursor 구현)
│           ├── ui/
│           │   ├── screens/      화면 (placeholder 포함)
│           │   ├── widgets/      공통 위젯
│           │   └── theme/        테마 토큰
│           └── mcp_bridge/       MCP sidecar 브리지
│
├── mcp/
│   └── sidecar/                  TypeScript MCP sidecar
│       └── src/
│
├── packages/
│   ├── archive_core/             순수 도메인 로직 (플랫폼 독립)
│   ├── archive_db/               SQLite 스키마, 마이그레이션
│   ├── archive_mcp_contract/     MCP tool 계약 정의
│   └── archive_shared/           공유 타입, 유틸
│
├── asset/
│   └── design/                   디자인 소스 (코드 asset과 분리)
│
├── docs/
│   ├── architecture/             이 문서들
│   ├── work_instructions/        작업지시문
│   ├── reports/                  완료보고서
│   └── handoff/                  에이전트 핸드오프 문서
│
├── test_fixtures/
│   └── sample_workspace/         테스트용 Markdown 샘플 Workspace
│
└── scripts/                      빌드, 마이그레이션 스크립트
```

---

## 각 폴더 책임

| 폴더 | 책임 | 금지 사항 |
|------|------|----------|
| `domain/models/` | 비즈니스 엔티티 정의 | Flutter/플랫폼 의존 금지 |
| `domain/services/` | 서비스 인터페이스 (abstract) | 구현 로직 금지 |
| `data/db/` | SQLite 구현체 | UI 코드 금지 |
| `data/file/` | 파일시스템 I/O | DB 직접 접근 금지 |
| `ui/` | Flutter 위젯 | DB/파일 직접 접근 금지 |
| `mcp_bridge/` | sidecar 프로세스 관리 | 비즈니스 로직 금지 |
| `mcp/sidecar/` | TypeScript MCP 서버 | DB 직접 무질서 조작 금지 |
| `asset/design/` | 디자인 소스 보관 | 앱 런타임 asset 혼재 금지 |

---

## 금지 사항 (전체)

- Flutter UI가 SQLite를 직접 조작하는 것
- MCP sidecar가 Markdown 파일을 ArchiveService 우회하여 직접 수정하는 것
- Windows 절대경로 하드코딩
- 디자인 소스와 앱 런타임 asset 혼재
- AI가 사용자 승인 없이 개인 아카이브에 데이터를 확정 저장하는 것
- sync_journal 없이 AI가 문서를 수정하는 것

---

*Updated: 2026-06-05*
