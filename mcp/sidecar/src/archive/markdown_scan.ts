// markdown_scan.ts — SQLite index 없을 때 markdown read-only fallback

import fs from 'node:fs';
import path from 'node:path';

import type { WorkspaceContext } from './workspace.js';
import { parseMarkdownPreview } from './frontmatter.js';
import type { DocumentDetail, DocumentListItem, SearchResultItem } from './sqlite_reader.js';

type ScannedDoc = {
  id: string;
  title: string;
  relativePath: string;
  category: string | null;
  project: string | null;
  author: string | null;
  tags: string[];
  updatedAt: string;
  preview: string;
};

/** workspace markdown 파일을 스캔한다. */
export class MarkdownScanReader {
  private readonly docs: ScannedDoc[];

  constructor(ctx: WorkspaceContext) {
    this.docs = scanMarkdownFiles(ctx.root);
  }

  countDocuments(): number {
    return this.docs.length;
  }

  listDocuments(args: {
    limit: number;
    offset: number;
    category?: string;
    project?: string;
  }): DocumentListItem[] {
    return this.filterDocs(args)
      .slice(args.offset, args.offset + args.limit)
      .map((doc) => ({
        id: doc.id,
        title: doc.title,
        relativePath: doc.relativePath,
        category: doc.category,
        project: doc.project,
        updatedAt: doc.updatedAt,
        source: 'markdown_scan' as const,
      }));
  }

  searchDocuments(args: {
    text: string;
    limit: number;
    category?: string;
    project?: string;
  }): SearchResultItem[] {
    const needle = args.text.trim().toLowerCase();
    if (!needle) return [];
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
        source: 'markdown_scan' as const,
      }));
  }

  getDocument(id: string): DocumentDetail | null {
    const doc = this.docs.find((item) => item.id === id);
    if (!doc) return null;
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

  private filterDocs(args: { category?: string; project?: string }): ScannedDoc[] {
    return this.docs.filter((doc) => {
      if (args.category && doc.category !== args.category) return false;
      if (args.project && doc.project !== args.project) return false;
      return true;
    });
  }
}

/** workspace에서 markdown 파일을 재귀 스캔한다. */
function scanMarkdownFiles(workspaceRoot: string): ScannedDoc[] {
  const results: ScannedDoc[] = [];
  walkDir(workspaceRoot, workspaceRoot, results);
  results.sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  return results;
}

/** 디렉터리를 재귀 순회한다. */
function walkDir(workspaceRoot: string, currentDir: string, results: ScannedDoc[]): void {
  let entries: fs.Dirent[];
  try {
    entries = fs.readdirSync(currentDir, { withFileTypes: true });
  } catch {
    return;
  }

  for (const entry of entries) {
    const fullPath = path.join(currentDir, entry.name);
    const rel = path.relative(workspaceRoot, fullPath).replace(/\\/g, '/');
    if (entry.isDirectory()) {
      if (rel === '.sac' || rel.startsWith('.sac/')) continue;
      walkDir(workspaceRoot, fullPath, results);
      continue;
    }
    if (!entry.isFile() || !entry.name.toLowerCase().endsWith('.md')) continue;
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
    } catch {
      // unreadable file skip
    }
  }
}
