import type { WorkspaceContext } from './workspace.js';
import type { DocumentDetail, DocumentListItem, SearchResultItem } from './sqlite_reader.js';
/** workspace markdown 파일을 스캔한다. */
export declare class MarkdownScanReader {
    private readonly docs;
    constructor(ctx: WorkspaceContext);
    countDocuments(): number;
    listDocuments(args: {
        limit: number;
        offset: number;
        category?: string;
        project?: string;
    }): DocumentListItem[];
    searchDocuments(args: {
        text: string;
        limit: number;
        category?: string;
        project?: string;
    }): SearchResultItem[];
    getDocument(id: string): DocumentDetail | null;
    private filterDocs;
}
