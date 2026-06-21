import type { WorkspaceContext } from './workspace.js';
export type ArchiveSource = 'sqlite' | 'markdown_scan';
export type DocumentListItem = {
    id: string;
    title: string;
    relativePath: string;
    category: string | null;
    project: string | null;
    updatedAt: string;
    source: ArchiveSource;
};
export type SearchResultItem = DocumentListItem & {
    snippet: string;
    score: number | null;
};
export type DocumentDetail = {
    id: string;
    title: string;
    relativePath: string;
    category: string | null;
    project: string | null;
    author: string | null;
    tags: string[];
    updatedAt: string;
    preview: string;
    includeFullBody: false;
    source: ArchiveSource;
};
/** SQLite index 기반 archive reader. */
export declare class SqliteArchiveReader {
    private readonly db;
    private readonly workspaceId;
    private readonly workspaceRoot;
    constructor(ctx: WorkspaceContext);
    /** workspace 문서 수를 반환한다. */
    countDocuments(): number;
    /** 문서 목록을 반환한다. */
    listDocuments(args: {
        limit: number;
        offset: number;
        category?: string;
        project?: string;
    }): DocumentListItem[];
    /** FTS 검색을 수행한다. */
    searchDocuments(args: {
        text: string;
        limit: number;
        category?: string;
        project?: string;
    }): SearchResultItem[];
    /** 문서 metadata + preview를 반환한다. */
    getDocument(id: string, includeFullBody?: boolean): DocumentDetail | null;
    /** app_settings를 읽는다. */
    readSettings(): Record<string, string>;
    close(): void;
}
