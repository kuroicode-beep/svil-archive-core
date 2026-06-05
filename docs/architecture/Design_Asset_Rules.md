---
title: "SAC Design Asset Rules"
author: "Claude Code (Sonnet)"
project: "SAC"
type: "디자인 소스 규칙"
status: "active"
created: "2026-06-05"
---

# SAC Design Asset 관리 규칙

---

## 기본 원칙

디자인 소스와 앱 런타임 asset은 반드시 분리한다.

| 구분 | 위치 | 설명 |
|------|------|------|
| 디자인 소스 | `asset/design/` | Stitch, Claude Design, Figma 결과물 등 |
| 앱 런타임 asset | `app/flutter_app/assets/` | Flutter 앱이 실제 번들하는 이미지, 폰트 등 |

---

## 디자인 소스 폴더 구조

```
asset/design/
├── stitch/           Stitch 생성 화면, 스크린샷, export
├── claude_design/    Claude Design 결과물
├── figma/            Figma export / handoff 자료
├── references/       참고 이미지, 레이아웃 자료
├── exports/          최종 디자인 산출물
└── README.md         이 규칙 문서
```

---

## 파일명 규칙

```
YYYYMMDD_[화면명]_[버전]_[도구].png
예: 20260605_dashboard_v1_stitch.png
    20260605_doc_editor_v2_figma.pdf
```

---

## Git 관리

- 소용량 스크린샷/PNG: 일반 Git 커밋
- 대용량 export 파일 (Figma 원본, 고해상도 ZIP 등): Git LFS 사용 여부 후속 결정
- `asset/design/` 폴더는 `.gitignore`에서 제외 (추적 대상)

---

## 금지 사항

- `app/flutter_app/assets/`에 디자인 작업 소스 저장 금지
- `asset/design/`에 앱 런타임에 필요한 파일 저장 금지
- 파일명에 한글 사용 금지 (경로 인코딩 문제)

---

*Updated: 2026-06-05*
