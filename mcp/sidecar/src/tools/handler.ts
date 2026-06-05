// Tool 핸들러 — Phase 1 Stub
// 실제 ArchiveService 연결은 Cursor Sprint 2에서 구현

type ToolResult = {
  content: Array<{ type: 'text'; text: string }>;
  isError?: boolean;
};

export async function handleToolCall(
  name: string,
  args: Record<string, unknown>
): Promise<ToolResult> {
  // Phase 1: 모든 tool이 stub 응답 반환
  switch (name) {
    case 'list_documents':
    case 'get_document':
    case 'create_document':
    case 'update_document':
    case 'search_documents':
    case 'move_document_to_trash':
    case 'restore_document_from_trash':
    case 'get_settings':
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              status: 'stub',
              message: `[Phase 1 Stub] ${name} — Cursor Sprint 2에서 구현됩니다.`,
              received_args: args,
            }),
          },
        ],
      };

    default:
      return {
        content: [{ type: 'text', text: `Unknown tool: ${name}` }],
        isError: true,
      };
  }
}
