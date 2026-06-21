// archive_service.ts — SAC archive read-only MCP backend
import { SacArchiveError } from './errors.js';
import { maskSensitiveValue } from './path_masking.js';
import { MarkdownScanReader } from './markdown_scan.js';
import { SqliteArchiveReader } from './sqlite_reader.js';
import { resolveWorkspaceContext } from './workspace.js';
const WRITE_TOOLS = new Set([
    'create_document',
    'update_document',
    'restore_document_from_trash',
    'move_document_to_trash',
]);
/** SAC archive read-only 서비스. */
export class SacArchiveService {
    ctx = resolveWorkspaceContext();
    source;
    reader;
    sqliteReader = null;
    constructor() {
        if (this.ctx.indexDbExists) {
            this.sqliteReader = new SqliteArchiveReader(this.ctx);
            this.reader = this.sqliteReader;
            this.source = 'sqlite';
        }
        else {
            this.reader = new MarkdownScanReader(this.ctx);
            this.source = 'markdown_scan';
        }
    }
    /** write/destructive tool 요청을 거부한다. */
    assertReadOnlyTool(toolName) {
        if (WRITE_TOOLS.has(toolName)) {
            throw new SacArchiveError('QUEUE_APPROVAL_REQUIRED', `${toolName} requires Work Queue approval in SAC app`);
        }
    }
    /** workspace 상태를 반환한다. */
    getWorkspaceStatus() {
        const warnings = [];
        if (!this.ctx.indexDbExists) {
            warnings.push('SQLite index missing — using markdown_scan fallback');
        }
        return {
            ok: true,
            workspaceRoot: this.ctx.maskedRoot,
            exists: true,
            indexDbExists: this.ctx.indexDbExists,
            documentCount: this.reader.countDocuments(),
            source: this.source,
            privacyMode: 'local-only',
            externalApiEnabled: false,
            remoteMcpEnabled: false,
            warnings,
        };
    }
    /** 설정 요약을 반환한다. */
    getSettings() {
        const settingsMap = this.sqliteReader?.readSettings() ??
            {
                external_api_enabled: 'false',
                mcp_enabled: 'false',
            };
        const maskedEntries = Object.entries(settingsMap).map(([key, value]) => [
            key,
            maskSensitiveValue(key, value),
        ]);
        return {
            ok: true,
            source: this.source,
            workspaceRoot: this.ctx.maskedRoot,
            settings: Object.fromEntries(maskedEntries),
            privacy: {
                localOnly: true,
                externalApiEnabled: settingsMap.external_api_enabled === 'true' ? false : false,
                remoteMcpEnabled: false,
            },
            mcp: {
                enabled: settingsMap.mcp_enabled === 'true',
                localOnly: true,
                remoteExposureEnabled: false,
            },
            toolPermissions: {
                writeTools: 'queue_approval_required',
                destructiveTools: 'queue_approval_required',
            },
        };
    }
    /** 문서 목록을 반환한다. */
    listDocuments(args) {
        const limit = clampNumber(args.limit, 20, 1, 100);
        const offset = clampNumber(args.offset, 0, 0, 10_000);
        const category = stringOrUndefined(args.type ?? args.category);
        const project = stringOrUndefined(args.project);
        const items = this.reader.listDocuments({ limit, offset, category, project });
        return {
            ok: true,
            source: this.source,
            workspaceRoot: this.ctx.maskedRoot,
            count: items.length,
            documents: items,
            warnings: this.ctx.indexDbExists ? [] : ['markdown_scan fallback active'],
        };
    }
    /** 문서 metadata/preview를 반환한다. */
    getDocument(args) {
        const id = stringOrUndefined(args.id);
        if (!id) {
            throw new SacArchiveError('DOCUMENT_NOT_FOUND', 'Document id is required');
        }
        if (args.include_full_body === true || args.includeFullBody === true) {
            throw new SacArchiveError('QUEUE_APPROVAL_REQUIRED', 'Full body export is not allowed by default');
        }
        const doc = this.reader instanceof SqliteArchiveReader
            ? this.reader.getDocument(id, false)
            : this.reader.getDocument(id);
        if (!doc) {
            throw new SacArchiveError('DOCUMENT_NOT_FOUND', `Document not found: ${id}`);
        }
        return { ok: true, source: this.source, document: doc };
    }
    /** 검색 결과를 반환한다. */
    searchDocuments(args) {
        const text = stringOrUndefined(args.text ?? args.query);
        if (!text) {
            return { ok: true, source: this.source, count: 0, results: [] };
        }
        const limit = clampNumber(args.limit, 20, 1, 100);
        const category = stringOrUndefined(args.type ?? args.category);
        const project = stringOrUndefined(args.project);
        const results = this.reader.searchDocuments({ text, limit, category, project });
        return {
            ok: true,
            source: this.source,
            workspaceRoot: this.ctx.maskedRoot,
            count: results.length,
            results,
            warnings: this.ctx.indexDbExists ? [] : ['markdown_scan fallback active'],
        };
    }
    close() {
        this.sqliteReader?.close();
    }
}
/** optional string 인자를 정규화한다. */
function stringOrUndefined(value) {
    if (typeof value !== 'string')
        return undefined;
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
}
/** 숫자 인자를 clamp한다. */
function clampNumber(value, fallback, min, max) {
    const num = typeof value === 'number' ? value : Number(value);
    if (!Number.isFinite(num))
        return fallback;
    return Math.max(min, Math.min(max, Math.floor(num)));
}
