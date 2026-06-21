export type WorkspaceContext = {
    root: string;
    maskedRoot: string;
    indexDbPath: string;
    indexDbExists: boolean;
};
/** SAC_WORKSPACE_ROOT를 해석하고 검증한다. */
export declare function resolveWorkspaceContext(): WorkspaceContext;
