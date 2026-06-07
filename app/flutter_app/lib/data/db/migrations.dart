// migrations.dart — SQLite 스키마 버전 및 migration SQL 정의

import 'package:sqflite/sqflite.dart';

const int kSacSchemaVersion = 7;

/// Sprint 2 초기 스키마 migration SQL 목록을 반환한다.
List<String> sprint2MigrationSql() {
  return [
    '''
    CREATE TABLE IF NOT EXISTS workspaces (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      root_path TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL,
      last_opened_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS documents (
      id TEXT PRIMARY KEY,
      workspace_id TEXT NOT NULL,
      relative_path TEXT NOT NULL UNIQUE,
      title TEXT NOT NULL,
      category TEXT,
      tags TEXT,
      content_hash TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_indexed_at TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(workspace_id) REFERENCES workspaces(id)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS sync_state (
      document_id TEXT PRIMARY KEY,
      revision INTEGER NOT NULL DEFAULT 1,
      base_revision INTEGER NOT NULL DEFAULT 1,
      status TEXT NOT NULL DEFAULT 'clean',
      last_actor TEXT,
      last_user_edit_at TEXT,
      last_ai_edit_at TEXT,
      dirty INTEGER NOT NULL DEFAULT 0,
      conflict INTEGER NOT NULL DEFAULT 0,
      locked INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS sync_journal (
      id TEXT PRIMARY KEY,
      document_id TEXT NOT NULL,
      actor TEXT NOT NULL,
      action TEXT NOT NULL,
      revision INTEGER,
      note TEXT,
      occurred_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS document_chunks (
      id TEXT PRIMARY KEY,
      document_id TEXT NOT NULL,
      chunk_index INTEGER NOT NULL,
      heading_path TEXT,
      content TEXT NOT NULL,
      token_count INTEGER,
      created_at TEXT NOT NULL,
      FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS trash_items (
      id TEXT PRIMARY KEY,
      document_id TEXT NOT NULL,
      original_path TEXT NOT NULL,
      trashed_at TEXT NOT NULL,
      trashed_by TEXT,
      FOREIGN KEY(document_id) REFERENCES documents(id)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS mcp_events (
      id TEXT PRIMARY KEY,
      agent_id TEXT,
      tool_name TEXT NOT NULL,
      params_json TEXT,
      result TEXT,
      occurred_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS audit_logs (
      id TEXT PRIMARY KEY,
      actor TEXT NOT NULL,
      action TEXT NOT NULL,
      target_type TEXT,
      target_id TEXT,
      detail_json TEXT,
      occurred_at TEXT NOT NULL
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_documents_workspace ON documents(workspace_id)',
    'CREATE INDEX IF NOT EXISTS idx_documents_updated ON documents(updated_at)',
    'CREATE INDEX IF NOT EXISTS idx_sync_journal_document ON sync_journal(document_id)',
  ];
}

/// Sprint 3 FTS / chunk 확장 migration SQL 목록을 반환한다.
List<String> sprint3MigrationSql() {
  return [
    'ALTER TABLE document_chunks ADD COLUMN content_hash TEXT',
    'ALTER TABLE document_chunks ADD COLUMN updated_at TEXT',
    '''
    CREATE VIRTUAL TABLE IF NOT EXISTS document_fts USING fts5(
      document_id UNINDEXED,
      title,
      heading,
      content,
      tags,
      category,
      tokenize='unicode61'
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_chunks_document_id ON document_chunks(document_id)',
    'CREATE INDEX IF NOT EXISTS idx_trash_document ON trash_items(document_id)',
  ];
}

/// Sprint 4 문서 메타데이터 확장 migration SQL 목록을 반환한다.
List<String> sprint4MigrationSql() {
  return [
    'ALTER TABLE documents ADD COLUMN author TEXT',
    'ALTER TABLE documents ADD COLUMN project TEXT',
    'ALTER TABLE documents ADD COLUMN summary TEXT',
  ];
}

/// Sprint 5 개인 아카이브 migration SQL 목록을 반환한다.
List<String> sprint5MigrationSql() {
  return [
    '''
    CREATE TABLE IF NOT EXISTS personal_archive_items (
      id TEXT PRIMARY KEY,
      item_type TEXT NOT NULL,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      source_document_id TEXT,
      source_path TEXT,
      confidence REAL,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS personal_extraction_queue (
      id TEXT PRIMARY KEY,
      source_document_id TEXT,
      source_path TEXT,
      candidate_type TEXT NOT NULL,
      candidate_title TEXT NOT NULL,
      candidate_content TEXT NOT NULL,
      confidence REAL,
      reason TEXT,
      status TEXT NOT NULL DEFAULT 'pending',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS journal_comments (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      mood TEXT,
      tags TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_personal_archive_status ON personal_archive_items(status)',
    'CREATE INDEX IF NOT EXISTS idx_extraction_queue_status ON personal_extraction_queue(status)',
  ];
}

/// Sprint 7 MCP / Work Queue migration SQL 목록을 반환한다.
List<String> sprint7MigrationSql() {
  return [
    '''
    CREATE TABLE IF NOT EXISTS work_queue_tickets (
      id TEXT PRIMARY KEY,
      actor TEXT NOT NULL,
      requested_action TEXT NOT NULL,
      target_type TEXT NOT NULL,
      target_id TEXT,
      target_path TEXT,
      permission_level TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      priority INTEGER NOT NULL DEFAULT 5,
      reason TEXT,
      error_message TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS mcp_tool_settings (
      tool_name TEXT PRIMARY KEY,
      enabled INTEGER NOT NULL DEFAULT 0,
      permission_level TEXT NOT NULL,
      description TEXT,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS permission_tokens (
      id TEXT PRIMARY KEY,
      token_type TEXT NOT NULL,
      actor TEXT NOT NULL,
      scope TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active',
      expires_at TEXT,
      created_at TEXT NOT NULL
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_work_queue_status ON work_queue_tickets(status)',
    'CREATE INDEX IF NOT EXISTS idx_work_queue_created ON work_queue_tickets(created_at)',
    'CREATE INDEX IF NOT EXISTS idx_permission_tokens_status ON permission_tokens(status)',
  ];
}

/// Sprint 8 ticket execution migration SQL 목록을 반환한다.
List<String> sprint8MigrationSql() {
  return [
    'ALTER TABLE work_queue_tickets ADD COLUMN base_revision INTEGER',
    'ALTER TABLE work_queue_tickets ADD COLUMN permission_token_id TEXT',
    'ALTER TABLE work_queue_tickets ADD COLUMN payload_json TEXT',
    '''
    CREATE TABLE IF NOT EXISTS ticket_execution_logs (
      id TEXT PRIMARY KEY,
      ticket_id TEXT NOT NULL,
      action TEXT NOT NULL,
      target_path TEXT,
      result_status TEXT NOT NULL,
      error_code TEXT,
      error_message TEXT,
      revision_before INTEGER,
      revision_after INTEGER,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS ticket_dry_run_previews (
      id TEXT PRIMARY KEY,
      ticket_id TEXT NOT NULL,
      summary TEXT NOT NULL,
      risk_level TEXT NOT NULL,
      preview_status TEXT NOT NULL DEFAULT 'ready',
      created_at TEXT NOT NULL,
      expires_at TEXT
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_execution_logs_ticket ON ticket_execution_logs(ticket_id)',
    'CREATE INDEX IF NOT EXISTS idx_dry_run_ticket ON ticket_dry_run_previews(ticket_id)',
  ];
}

/// 스키마 버전에 맞는 migration을 적용한다.
Future<void> applySacMigrations(Database db, int fromVersion, int toVersion) async {
  if (fromVersion < 1) {
    for (final sql in sprint2MigrationSql()) {
      await db.execute(sql);
    }
  }
  if (fromVersion < 2) {
    for (final sql in sprint3MigrationSql()) {
      try {
        await db.execute(sql);
      } catch (e) {
        // ALTER ADD COLUMN 중복만 무시 — FTS/인덱스 생성 실패는 전파한다.
        final msg = e.toString().toLowerCase();
        if (!msg.contains('duplicate column')) {
          rethrow;
        }
      }
    }
  }
  if (fromVersion < 3) {
    for (final sql in sprint4MigrationSql()) {
      try {
        await db.execute(sql);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (!msg.contains('duplicate column')) {
          rethrow;
        }
      }
    }
  }
  if (fromVersion < 4) {
    for (final sql in sprint5MigrationSql()) {
      await db.execute(sql);
    }
  }
  if (fromVersion < 5) {
    for (final sql in sprint7MigrationSql()) {
      await db.execute(sql);
    }
  }
  if (fromVersion < 6) {
    for (final sql in sprint8MigrationSql()) {
      try {
        await db.execute(sql);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (!msg.contains('duplicate column')) {
          rethrow;
        }
      }
    }
  }
  if (fromVersion < 7) {
    for (final sql in sprint9MigrationSql()) {
      try {
        await db.execute(sql);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (!msg.contains('duplicate column')) {
          rethrow;
        }
      }
    }
  }
}

/// Sprint 9 integrity / smoke migration SQL 목록을 반환한다.
List<String> sprint9MigrationSql() {
  return [
    'ALTER TABLE work_queue_tickets ADD COLUMN source_ticket_id TEXT',
    'ALTER TABLE work_queue_tickets ADD COLUMN recovery_kind TEXT',
    '''
    CREATE TABLE IF NOT EXISTS integrity_scan_runs (
      id TEXT PRIMARY KEY,
      status TEXT NOT NULL,
      orphan_count INTEGER NOT NULL DEFAULT 0,
      stale_db_count INTEGER NOT NULL DEFAULT 0,
      conflict_count INTEGER NOT NULL DEFAULT 0,
      warning_count INTEGER NOT NULL DEFAULT 0,
      started_at TEXT NOT NULL,
      completed_at TEXT,
      error_message TEXT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS integrity_scan_items (
      id TEXT PRIMARY KEY,
      scan_run_id TEXT NOT NULL,
      item_type TEXT NOT NULL,
      target_path TEXT,
      document_id TEXT,
      severity TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'open',
      reason TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS smoke_test_records (
      id TEXT PRIMARY KEY,
      platform TEXT NOT NULL,
      checklist_name TEXT NOT NULL,
      status TEXT NOT NULL,
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_integrity_items_run ON integrity_scan_items(scan_run_id)',
    'CREATE INDEX IF NOT EXISTS idx_integrity_items_status ON integrity_scan_items(status)',
  ];
}
