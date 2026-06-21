// markdown_scan.ts — SQLite index 없을 때 markdown read-only fallback
import fs from 'node:fs';
import path from 'node:path';
import { parseMarkdownPreview } from './frontmatter.js';
/** workspace markdown 파일을 스캔한다. */
export class MarkdownScanReader {
    docs;
    constructor(ctx) {
        this.docs = scanMarkdownFiles(ctx.root);
    }
    countDocuments() {
        return this.docs.length;
    }
    listDocuments(args) {
        return this.filterDocs(args)
            .slice(args.offset, args.offset + args.limit)
            .map((doc) => ({
            id: doc.id,
            title: doc.title,
            relativePath: doc.relativePath,
            category: doc.category,
            project: doc.project,
            updatedAt: doc.updatedAt,
            source: 'markdown_scan',
        }));
    }
    searchDocuments(args) {
        const needle = args.text.trim().toLowerCase();
        if (!needle)
            return [];
        return this.filterDocs(args)
            .filter((doc) => {
            const hay = `${doc.title} ${doc.relativePath} ${doc.preview}`.toLowerCase();
            return hay.includes(needle);
        })
            .slice(0, args.limit)
            .map((doc) => ({
            id: doc.id,
            title: doc.title,
            relativePath: doc.relativePath,
            category: doc.category,
            project: doc.project,
            updatedAt: doc.updatedAt,
            snippet: doc.preview.slice(0, 160),
            score: null,
            source: 'markdown_scan',
        }));
    }
    getDocument(id) {
        const doc = this.docs.find((item) => item.id === id);
        if (!doc)
            return null;
        return {
            id: doc.id,
            title: doc.title,
            relativePath: doc.relativePath,
            category: doc.category,
            project: doc.project,
            author: doc.author,
            tags: doc.tags,
            updatedAt: doc.updatedAt,
            preview: doc.preview,
            includeFullBody: false,
            source: 'markdown_scan',
        };
    }
    filterDocs(args) {
        return this.docs.filter((doc) => {
            if (args.category && doc.category !== args.category)
                return false;
            if (args.project && doc.project !== args.project)
                return false;
            return true;
        });
    }
}
/** workspace에서 markdown 파일을 재귀 스캔한다. */
function scanMarkdownFiles(workspaceRoot) {
    const results = [];
    walkDir(workspaceRoot, workspaceRoot, results);
    results.sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
    return results;
}
/** 디렉터리를 재귀 순회한다. */
function walkDir(workspaceRoot, currentDir, results) {
    let entries;
    try {
        entries = fs.readdirSync(currentDir, { withFileTypes: true });
    }
    catch {
        return;
    }
    for (const entry of entries) {
        const fullPath = path.join(currentDir, entry.name);
        const rel = path.relative(workspaceRoot, fullPath).replace(/\\/g, '/');
        if (entry.isDirectory()) {
            if (rel === '.sac' || rel.startsWith('.sac/'))
                continue;
            walkDir(workspaceRoot, fullPath, results);
            continue;
        }
        if (!entry.isFile() || !entry.name.toLowerCase().endsWith('.md'))
            continue;
        try {
            const stat = fs.statSync(fullPath);
            const raw = fs.readFileSync(fullPath, 'utf8');
            const parsed = parseMarkdownPreview(raw);
            const id = parsed.sacId ?? rel;
            results.push({
                id,
                title: parsed.title ?? path.basename(entry.name, '.md'),
                relativePath: rel,
                category: parsed.category ?? null,
                project: parsed.project ?? null,
                author: parsed.author ?? null,
                tags: parsed.tags ?? [],
                updatedAt: stat.mtime.toISOString(),
                preview: parsed.preview,
            });
        }
        catch {
            // unreadable file skip
        }
    }
}
