// sqlite_reader.ts — SAC workspace SQLite read-only 조회
import fs from 'node:fs';
import path from 'node:path';
import Database from 'better-sqlite3';
import { parseMarkdownPreview } from './frontmatter.js';
/** SQLite index 기반 archive reader. */
export class SqliteArchiveReader {
    db;
    workspaceId;
    workspaceRoot;
    constructor(ctx) {
        if (!ctx.indexDbExists) {
            throw new Error('SQLite index not found');
        }
        this.db = new Database(ctx.indexDbPath, { readonly: true, fileMustExist: true });
        this.workspaceRoot = ctx.root;
        const row = this.db
            .prepare(`SELECT id FROM workspaces WHERE lower(replace(root_path, '\\', '/')) = lower(?) LIMIT 1`)
            .get(normalizePathKey(ctx.root));
        if (!row) {
            const fallback = this.db.prepare('SELECT id FROM workspaces ORDER BY last_opened_at DESC LIMIT 1').get();
            if (!fallback) {
                throw new Error('No workspace row in SQLite index');
            }
            this.workspaceId = fallback.id;
        }
        else {
            this.workspaceId = row.id;
        }
    }
    /** workspace 문서 수를 반환한다. */
    countDocuments() {
        const row = this.db
            .prepare(`SELECT COUNT(*) AS count FROM documents WHERE workspace_id = ? AND is_deleted = 0`)
            .get(this.workspaceId);
        return row.count ?? 0;
    }
    /** 문서 목록을 반환한다. */
    listDocuments(args) {
        const clauses = ['workspace_id = ?', 'is_deleted = 0'];
        const params = [this.workspaceId];
        if (args.category) {
            clauses.push('category = ?');
            params.push(args.category);
        }
        if (args.project) {
            clauses.push('project = ?');
            params.push(args.project);
        }
        params.push(args.limit, args.offset);
        const rows = this.db
            .prepare(`SELECT id, title, relative_path, category, project, updated_at
         FROM documents
         WHERE ${clauses.join(' AND ')}
         ORDER BY updated_at DESC
         LIMIT ? OFFSET ?`)
            .all(...params);
        return rows.map((row) => ({
            id: row.id,
            title: row.title,
            relativePath: normalizeRelativePath(row.relative_path),
            category: row.category,
            project: row.project,
            updatedAt: row.updated_at,
            source: 'sqlite',
        }));
    }
    /** FTS 검색을 수행한다. */
    searchDocuments(args) {
        const ftsQuery = escapeFtsQuery(args.text);
        const clauses = ['d.workspace_id = ?', 'd.is_deleted = 0', 'document_fts MATCH ?'];
        const params = [this.workspaceId, ftsQuery];
        if (args.category) {
            clauses.push('d.category = ?');
            params.push(args.category);
        }
        if (args.project) {
            clauses.push('d.project = ?');
            params.push(args.project);
        }
        params.push(args.limit);
        const rows = this.db
            .prepare(`SELECT d.id, d.title, d.relative_path, d.category, d.project, d.updated_at,
                snippet(document_fts, 3, '[', ']', '...', 48) AS snippet_text,
                bm25(document_fts) AS score
         FROM document_fts
         JOIN documents d ON d.id = document_fts.document_id
         WHERE ${clauses.join(' AND ')}
         ORDER BY score
         LIMIT ?`)
            .all(...params);
        return rows.map((row) => ({
            id: row.id,
            title: row.title,
            relativePath: normalizeRelativePath(row.relative_path),
            category: row.category,
            project: row.project,
            updatedAt: row.updated_at,
            snippet: (row.snippet_text ?? '').slice(0, 200),
            score: row.score,
            source: 'sqlite',
        }));
    }
    /** 문서 metadata + preview를 반환한다. */
    getDocument(id, includeFullBody = false) {
        if (includeFullBody) {
            throw new Error('FULL_BODY_NOT_ALLOWED');
        }
        const row = this.db
            .prepare(`SELECT id, title, relative_path, category, project, author, tags, updated_at
         FROM documents
         WHERE workspace_id = ? AND id = ? AND is_deleted = 0
         LIMIT 1`)
            .get(this.workspaceId, id);
        if (!row)
            return null;
        const filePath = path.join(this.workspaceRoot, row.relative_path);
        let preview = '';
        if (fs.existsSync(filePath)) {
            const raw = fs.readFileSync(filePath, 'utf8');
            preview = parseMarkdownPreview(raw).preview;
        }
        return {
            id: row.id,
            title: row.title,
            relativePath: normalizeRelativePath(row.relative_path),
            category: row.category,
            project: row.project,
            author: row.author,
            tags: parseTags(row.tags),
            updatedAt: row.updated_at,
            preview,
            includeFullBody: false,
            source: 'sqlite',
        };
    }
    /** app_settings를 읽는다. */
    readSettings() {
        const rows = this.db.prepare('SELECT key, value FROM app_settings').all();
        const map = {};
        for (const row of rows) {
            map[row.key] = row.value;
        }
        return map;
    }
    close() {
        this.db.close();
    }
}
/** FTS 쿼리 문자를 이스케이프한다. */
function escapeFtsQuery(input) {
    return input
        .trim()
        .split(/\s+/)
        .filter(Boolean)
        .map((token) => `"${token.replace(/"/g, '""')}"`)
        .join(' ');
}
/** tags 컬럼을 배열로 파싱한다. */
function parseTags(raw) {
    if (!raw)
        return [];
    try {
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed)) {
            return parsed.map(String);
        }
    }
    catch {
        // fallback comma split
    }
    return raw.split(',').map((t) => t.trim()).filter(Boolean);
}
/** workspace root 비교용 normalize. */
function normalizePathKey(value) {
    return value.replace(/\\/g, '/').replace(/\/+$/, '').toLowerCase();
}
/** relative path를 posix 스타일로 정규화한다. */
function normalizeRelativePath(value) {
    return value.replace(/\\/g, '/');
}
