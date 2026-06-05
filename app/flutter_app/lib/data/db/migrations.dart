// migrations.dart — SQLite 스키마 버전 및 migration SQL 정의

const int kSacSchemaVersion = 1;

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
