// workspace.ts — SAC_WORKSPACE_ROOT 해석
import fs from 'node:fs';
import path from 'node:path';
import { SacArchiveError } from './errors.js';
import { maskArtifactPath } from './path_masking.js';
/** sidecar.config.json에서 workspace root를 읽는다. */
function readConfigWorkspaceRoot() {
    const configPath = path.join(process.cwd(), 'sidecar.config.json');
    if (!fs.existsSync(configPath))
        return null;
    try {
        const parsed = JSON.parse(fs.readFileSync(configPath, 'utf8'));
        const candidate = parsed.workspaceRoot ?? parsed.SAC_WORKSPACE_ROOT;
        return candidate?.trim() || null;
    }
    catch {
        return null;
    }
}
/** SAC_WORKSPACE_ROOT를 해석하고 검증한다. */
export function resolveWorkspaceContext() {
    const envRoot = process.env.SAC_WORKSPACE_ROOT?.trim();
    const configRoot = readConfigWorkspaceRoot();
    const root = envRoot || configRoot;
    if (!root) {
        throw new SacArchiveError('SAC_WORKSPACE_ROOT_NOT_FOUND', 'Set SAC_WORKSPACE_ROOT environment variable or sidecar.config.json workspaceRoot');
    }
    const normalized = path.normalize(root);
    if (!fs.existsSync(normalized) || !fs.statSync(normalized).isDirectory()) {
        throw new SacArchiveError('SAC_WORKSPACE_ROOT_INVALID', `Workspace directory does not exist: ${maskArtifactPath(normalized)}`);
    }
    const indexDbPath = path.join(normalized, '.sac', 'sac.sqlite');
    return {
        root: normalized,
        maskedRoot: maskArtifactPath(normalized),
        indexDbPath,
        indexDbExists: fs.existsSync(indexDbPath),
    };
}
