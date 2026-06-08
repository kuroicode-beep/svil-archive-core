// archive.test.ts — Sprint 14 sidecar archive integration tests

import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, it } from 'node:test';

import Database from 'better-sqlite3';

import { containsAbsolutePathLeak, maskSensitiveValue } from '../src/archive/path_masking.js';
import { handleToolCall } from '../src/tools/handler.js';

let tempRoot = '';
const originalEnv = process.env.SAC_WORKSPACE_ROOT;

beforeEach(() => {
  tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sac_s14_'));
});

afterEach(() => {
  if (originalEnv === undefined) {
    delete process.env.SAC_WORKSPACE_ROOT;
  } else {
    process.env.SAC_WORKSPACE_ROOT = originalEnv;
  }
  if (tempRoot && fs.existsSync(tempRoot)) {
    fs.rmSync(tempRoot, { recursive: true, force: true });
  }
});

/** 테스트용 markdown 문서를 생성한다. */
function writeSampleMarkdown(relativePath: string, sacId: string, title: string, body: string) {
  const full = path.join(tempRoot, relativePath);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  const content = `---\nsac_id: ${sacId}\ntitle: ${title}\ncategory: Dev\nproject: SVIL\n---\n\n${body}\n`;
  fs.writeFileSync(full, content, 'utf8');
}

/** 최소 SQLite index를 생성한다. */
function writeSqliteIndex(docs: Array<{ id: string; title: string; relativePath: string; body: string }>) {
  const sacDir = path.join(tempRoot, '.sac');
  fs.mkdirSync(sacDir, { recursive: true });
  const dbPath = path.join(sacDir, 'sac.sqlite');
  const db = new Database(dbPath);
  db.exec(`
    CREATE TABLE workspaces (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      root_path TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL,
      last_opened_at TEXT NOT NULL
    );
    CREATE TABLE documents (
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
      project TEXT,
      author TEXT
    );
    CREATE VIRTUAL TABLE document_fts USING fts5(
      document_id UNINDEXED,
      title,
      heading,
      content,
      tags,
      category,
      tokenize='unicode61'
    );
    CREATE TABLE app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);
  const now = new Date().toISOString();
  db.prepare(
    'INSERT INTO workspaces (id, name, root_path, created_at, last_opened_at) VALUES (?, ?, ?, ?, ?)',
  ).run('ws-1', 'Test', tempRoot, now, now);
  for (const doc of docs) {
    db.prepare(
      `INSERT INTO documents
      (id, workspace_id, relative_path, title, category, tags, content_hash, created_at, updated_at, last_indexed_at, is_deleted, project, author)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)`,
    ).run(doc.id, 'ws-1', doc.relativePath, doc.title, 'Dev', '[]', 'hash', now, now, now, 'SVIL', 'tester');
    db.prepare(
      'INSERT INTO document_fts (document_id, title, heading, content, tags, category) VALUES (?, ?, ?, ?, ?, ?)',
    ).run(doc.id, doc.title, '', doc.body, '', 'Dev');
    writeSampleMarkdown(doc.relativePath, doc.id, doc.title, doc.body);
  }
  db.prepare('INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?)').run(
    'external_api_enabled',
    'false',
    now,
  );
  db.prepare('INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?)').run(
    'api_secret_token',
    'super-secret-token',
    now,
  );
  db.close();
}

/** tool JSON 응답을 파싱한다. */
async function callTool(name: string, args: Record<string, unknown> = {}) {
  const result = await handleToolCall(name, args);
  const text = result.content[0]?.text ?? '{}';
  return { json: JSON.parse(text) as Record<string, unknown>, isError: result.isError === true };
}

describe('Sprint 14 archive integration', () => {
  it('returns SAC_WORKSPACE_ROOT_NOT_FOUND when env missing', async () => {
    delete process.env.SAC_WORKSPACE_ROOT;
    const { json, isError } = await callTool('get_workspace_status');
    assert.equal(isError, true);
    assert.equal(json.error, 'SAC_WORKSPACE_ROOT_NOT_FOUND');
  });

  it('get_workspace_status uses sqlite source when index exists', async () => {
    process.env.SAC_WORKSPACE_ROOT = tempRoot;
    writeSqliteIndex([
      { id: 'doc-1', title: 'Alpha', relativePath: 'docs/Alpha.md', body: 'alpha content' },
    ]);
    const { json } = await callTool('get_workspace_status');
    assert.equal(json.ok, true);
    assert.equal(json.source, 'sqlite');
    assert.equal(json.documentCount, 1);
    assert.equal(json.externalApiEnabled, false);
    assert.equal(json.remoteMcpEnabled, false);
    assert.equal(containsAbsolutePathLeak(JSON.stringify(json)), false);
  });

  it('markdown scan fallback when sqlite missing', async () => {
    process.env.SAC_WORKSPACE_ROOT = tempRoot;
    writeSampleMarkdown('notes/Note.md', 'doc-md-1', 'Note', 'hello markdown fallback');
    const { json } = await callTool('get_workspace_status');
    assert.equal(json.source, 'markdown_scan');
    assert.equal(json.documentCount, 1);
    assert.ok(Array.isArray(json.warnings));
  });

  it('list_documents returns relative paths only', async () => {
    process.env.SAC_WORKSPACE_ROOT = tempRoot;
    writeSqliteIndex([
      { id: 'doc-1', title: 'Alpha', relativePath: 'docs/Alpha.md', body: 'alpha' },
      { id: 'doc-2', title: 'Beta', relativePath: 'docs/Beta.md', body: 'beta' },
    ]);
    const { json } = await callTool('list_documents', { limit: 10 });
    const docs = json.documents as Array<{ relativePath: string }>;
    assert.equal(docs.length, 2);
    assert.ok(docs.every((d) => !d.relativePath.includes(':')));
    assert.equal(containsAbsolutePathLeak(JSON.stringify(json)), false);
  });

  it('get_settings masks sensitive values', async () => {
    process.env.SAC_WORKSPACE_ROOT = tempRoot;
    writeSqliteIndex([{ id: 'doc-1', title: 'Alpha', relativePath: 'docs/Alpha.md', body: 'alpha' }]);
    const { json } = await callTool('get_settings');
    const settings = json.settings as Record<string, string>;
    assert.equal(settings.api_secret_token, '***');
    assert.equal((json.privacy as { remoteMcpEnabled: boolean }).remoteMcpEnabled, false);
  });

  it('get_document returns preview not full body', async () => {
    process.env.SAC_WORKSPACE_ROOT = tempRoot;
    const body = 'x'.repeat(2000);
    writeSqliteIndex([{ id: 'doc-1', title: 'Alpha', relativePath: 'docs/Alpha.md', body }]);
    const { json } = await callTool('get_document', { id: 'doc-1' });
    const doc = json.document as { preview: string; includeFullBody: boolean };
    assert.equal(doc.includeFullBody, false);
    assert.ok(doc.preview.length < 500);
  });

  it('search_documents returns sqlite fts results', async () => {
    process.env.SAC_WORKSPACE_ROOT = tempRoot;
    writeSqliteIndex([
      { id: 'doc-1', title: 'Alpha', relativePath: 'docs/Alpha.md', body: 'uniquekeyword alpha' },
      { id: 'doc-2', title: 'Beta', relativePath: 'docs/Beta.md', body: 'other text' },
    ]);
    const { json } = await callTool('search_documents', { text: 'uniquekeyword' });
    const results = json.results as Array<{ id: string }>;
    assert.ok(results.length >= 1);
    assert.equal(results[0]?.id, 'doc-1');
  });

  it('write tools return QUEUE_APPROVAL_REQUIRED', async () => {
    process.env.SAC_WORKSPACE_ROOT = tempRoot;
    const { json, isError } = await callTool('create_document', {
      title: 'X',
      relative_dir: 'docs',
      token: 't',
      agent_id: 'a',
    });
    assert.equal(isError, true);
    assert.equal(json.error, 'QUEUE_APPROVAL_REQUIRED');
  });
});
