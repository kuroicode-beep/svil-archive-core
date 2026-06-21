import { type ArchiveSource } from './sqlite_reader.js';
/** SAC archive read-only 서비스. */
export declare class SacArchiveService {
    private readonly ctx;
    private readonly source;
    private readonly reader;
    private sqliteReader;
    constructor();
    /** write/destructive tool 요청을 거부한다. */
    assertReadOnlyTool(toolName: string): void;
    /** workspace 상태를 반환한다. */
    getWorkspaceStatus(): {
        ok: boolean;
        workspaceRoot: string;
        exists: boolean;
        indexDbExists: boolean;
        documentCount: number;
        source: ArchiveSource;
        privacyMode: string;
        externalApiEnabled: boolean;
        remoteMcpEnabled: boolean;
        warnings: string[];
    };
    /** 설정 요약을 반환한다. */
    getSettings(): {
        ok: boolean;
        source: ArchiveSource;
        workspaceRoot: string;
        settings: any;
        privacy: {
            localOnly: boolean;
            externalApiEnabled: boolean;
            remoteMcpEnabled: boolean;
        };
        mcp: {
            enabled: boolean;
            localOnly: boolean;
            remoteExposureEnabled: boolean;
        };
        toolPermissions: {
            writeTools: string;
            destructiveTools: string;
        };
    };
    /** 문서 목록을 반환한다. */
    listDocuments(args: Record<string, unknown>): {
        ok: boolean;
        source: ArchiveSource;
        workspaceRoot: string;
        count: number;
        documents: import("./sqlite_reader.js").DocumentListItem[];
        warnings: string[];
    };
    /** 문서 metadata/preview를 반환한다. */
    getDocument(args: Record<string, unknown>): {
        ok: boolean;
        source: ArchiveSource;
        document: import("./sqlite_reader.js").DocumentDetail;
    };
    /** 검색 결과를 반환한다. */
    searchDocuments(args: Record<string, unknown>): {
        ok: boolean;
        source: ArchiveSource;
        count: number;
        results: never[];
        workspaceRoot?: undefined;
        warnings?: undefined;
    } | {
        ok: boolean;
        source: ArchiveSource;
        workspaceRoot: string;
        count: number;
        results: import("./sqlite_reader.js").SearchResultItem[];
        warnings: string[];
    };
    close(): void;
}
