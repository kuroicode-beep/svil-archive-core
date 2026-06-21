export type SacArchiveErrorCode = 'SAC_WORKSPACE_ROOT_NOT_FOUND' | 'SAC_WORKSPACE_ROOT_INVALID' | 'DOCUMENT_NOT_FOUND' | 'QUEUE_APPROVAL_REQUIRED';
export declare class SacArchiveError extends Error {
    readonly code: SacArchiveErrorCode;
    constructor(code: SacArchiveErrorCode, message: string);
    toJSON(): {
        ok: boolean;
        error: SacArchiveErrorCode;
        message: string;
    };
}
