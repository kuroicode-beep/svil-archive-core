// handler.ts — MCP tool 실행 (Sprint 14 archive 연동)

import { SacArchiveService } from '../archive/archive_service.js';
import { SacArchiveError } from '../archive/errors.js';

type ToolResult = {
  content: Array<{ type: 'text'; text: string }>;
  isError?: boolean;
};

const WRITE_TOOLS = new Set([
  'create_document',
  'update_document',
  'restore_document_from_trash',
  'move_document_to_trash',
]);

/** MCP tool 호출을 처리한다. */
export async function handleToolCall(
  name: string,
  args: Record<string, unknown>,
): Promise<ToolResult> {
  if (WRITE_TOOLS.has(name)) {
    return toolJson(
      {
        ok: false,
        error: 'QUEUE_APPROVAL_REQUIRED',
        message: `${name} requires Work Queue approval in SAC app`,
      },
      true,
    );
  }

  let service: SacArchiveService;
  try {
    service = new SacArchiveService();
  } catch (error) {
    if (error instanceof SacArchiveError) {
      return toolJson(error.toJSON(), true);
    }
    throw error;
  }

  try {
    let payload: unknown;
    switch (name) {
      case 'get_workspace_status':
        payload = service.getWorkspaceStatus();
        break;
      case 'get_settings':
        payload = service.getSettings();
        break;
      case 'list_documents':
        payload = service.listDocuments(args);
        break;
      case 'get_document':
        payload = service.getDocument(args);
        break;
      case 'search_documents':
        payload = service.searchDocuments(args);
        break;
      default:
        return toolJson({ ok: false, error: 'UNKNOWN_TOOL', message: `Unknown tool: ${name}` }, true);
    }
    return toolJson(payload, false);
  } catch (error) {
    if (error instanceof SacArchiveError) {
      return toolJson(error.toJSON(), true);
    }
    const message = error instanceof Error ? error.message : String(error);
    return toolJson({ ok: false, error: 'INTERNAL_ERROR', message }, true);
  } finally {
    service.close();
  }
}

/** tool 응답 JSON을 MCP content로 변환한다. */
function toolJson(payload: unknown, isError: boolean): ToolResult {
  return {
    content: [{ type: 'text', text: JSON.stringify(payload) }],
    isError,
  };
}
