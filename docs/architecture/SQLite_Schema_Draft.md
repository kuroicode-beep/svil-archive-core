---
title: "SAC SQLite Schema Draft"
author: "Claude Code (Sonnet)"
project: "SAC"
type: "DB 스키마 초안"
status: "draft"
created: "2026-06-05"
---

# SAC SQLite Schema Draft — Phase 1

전제: SQLite WAL 모드 사용. DB 위치: `{workspace_root}/.sac/sac.sqlite`

---

## Phase 1 구현 테이블

### workspaces

```sql
CREATE TABLE workspaces (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  root_path TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL,
  last_opened_at TEXT NOT NULL
);
```

---

### documents

```sql
CREATE TABLE documents (
  id TEXT PRIMARY KEY,              -- sac_id (UUID)
  path TEXT NOT NULL UNIQUE,        -- Workspace 기준 상대경로
  title TEXT NOT NULL,
  author TEXT,
  project TEXT,
  type TEXT,
  status TEXT NOT NULL DEFAULT 'active',  -- active | archived | trashed
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  tags TEXT,                        -- JSON 배열
  summary TEXT,
  content_hash TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1,
  sac_schema TEXT NOT NULL DEFAULT '1',
  metadata_json TEXT                -- 기타 frontmatter 전체
);

CREATE INDEX idx_documents_project ON documents(project);
CREATE INDEX idx_documents_type ON documents(type);
CREATE INDEX idx_documents_status ON documents(status);
CREATE INDEX idx_documents_updated_at ON documents(updated_at);
```

---

### document_chunks

```sql
CREATE TABLE document_chunks (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  chunk_index INTEGER NOT NULL,
  heading_path TEXT,
  content TEXT NOT NULL,
  token_count INTEGER,
  created_at TEXT NOT NULL,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
);

CREATE INDEX idx_chunks_document_id ON document_chunks(document_id);
```

---

### document_fts (FTS5 전문 검색)

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
-- 한국어 검색 tokenizer는 Cursor Sprint 2에서 결정 (mecab / ngram 등)
```

---

### trash_items

```sql
CREATE TABLE trash_items (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  original_path TEXT NOT NULL,
  trashed_at TEXT NOT NULL,
  trashed_by TEXT,                  -- 'user' | AI agent ID
  FOREIGN KEY(document_id) REFERENCES documents(id)
);
```

---

### sync_state

```sql
CREATE TABLE sync_state (
  document_id TEXT PRIMARY KEY,
  status TEXT NOT NULL,             -- clean | dirty | user_modified | ai_pending | conflict | trashed
  last_user_edit_at TEXT,
  last_ai_edit_at TEXT,
  last_actor TEXT,
  revision INTEGER NOT NULL DEFAULT 1,
  base_revision INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
);
```

---

### sync_journal (Phase 1: append-only 기록, 복구 엔진 없음)

```sql
CREATE TABLE sync_journal (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  actor TEXT NOT NULL,              -- 'user' | AI agent ID
  action TEXT NOT NULL,             -- 'create' | 'update' | 'trash' | 'restore'
  revision INTEGER,
  note TEXT,
  occurred_at TEXT NOT NULL
);
-- 주의: Phase 1에서 복구 엔진 없음. 기록만 수행.
```

---

### app_settings / theme_settings / tts_settings

```sql
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE theme_settings (
  id INTEGER PRIMARY KEY CHECK(id = 1),
  theme TEXT NOT NULL DEFAULT 'light',
  high_contrast_enabled INTEGER NOT NULL DEFAULT 0,
  font_size_base REAL NOT NULL DEFAULT 16.0
);

CREATE TABLE tts_settings (
  id INTEGER PRIMARY KEY CHECK(id = 1),
  engine TEXT NOT NULL DEFAULT 'system',
  speed_multiplier REAL NOT NULL DEFAULT 1.0,
  highlight_current_sentence INTEGER NOT NULL DEFAULT 1
);
```

---

### mcp_events / audit_logs

```sql
CREATE TABLE mcp_events (
  id TEXT PRIMARY KEY,
  agent_id TEXT,
  tool_name TEXT NOT NULL,
  params_json TEXT,
  result TEXT,                      -- 'success' | 'rejected' | 'error'
  occurred_at TEXT NOT NULL
);

CREATE TABLE audit_logs (
  id TEXT PRIMARY KEY,
  actor TEXT NOT NULL,
  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  detail_json TEXT,
  occurred_at TEXT NOT NULL
);
```

---

## Phase 1 Placeholder 테이블 (스키마만, 구현 없음)

```sql
-- AI 에이전트 등록
CREATE TABLE ai_agents (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT,
  registered_at TEXT NOT NULL
);

-- 작업큐 / 티켓
CREATE TABLE work_tickets (
  id TEXT PRIMARY KEY,
  agent_id TEXT NOT NULL,
  tool_name TEXT NOT NULL,
  params_json TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL,
  completed_at TEXT,
  error_message TEXT
);

CREATE TABLE task_queue (
  id TEXT PRIMARY KEY,
  ticket_id TEXT NOT NULL,
  priority INTEGER NOT NULL DEFAULT 5,
  FOREIGN KEY(ticket_id) REFERENCES work_tickets(id)
);

-- 권한 토큰
CREATE TABLE permission_tokens (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,               -- write | destructive | admin
  issued_to TEXT NOT NULL,
  issued_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  document_id TEXT,
  revoked INTEGER NOT NULL DEFAULT 0
);

-- 개인 아카이브 (Phase 1: 자동 승인 금지 — 전부 수동 승인)
CREATE TABLE personal_profile_manual (
  id TEXT PRIMARY KEY,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  source_document_id TEXT,
  updated_at TEXT NOT NULL
);

CREATE TABLE personal_memory_comments (
  id TEXT PRIMARY KEY,
  document_id TEXT,
  comment TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE personal_extraction_queue (
  id TEXT PRIMARY KEY,
  source_document_id TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  confidence REAL,
  extracted_at TEXT NOT NULL,
  approved INTEGER              -- NULL=대기 | 1=승인 | 0=거절
);

CREATE TABLE personal_archive_items (
  id TEXT PRIMARY KEY,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  source_document_id TEXT,
  approved_at TEXT NOT NULL
);
```

---

*Updated: 2026-06-05 | Phase 1 Skeleton*
