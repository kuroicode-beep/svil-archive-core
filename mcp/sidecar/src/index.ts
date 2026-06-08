// SAC MCP Sidecar 진입점 — Sprint 14 archive read-only integration
// Transport: stdio (JSON-RPC over stdin/stdout)

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { toolDefinitions } from './tools/definitions.js';
import { handleToolCall } from './tools/handler.js';

const server = new Server(
  { name: 'sac-mcp-sidecar', version: '0.1.0' },
  { capabilities: { tools: {} } }
);

// tool 목록 반환
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: toolDefinitions,
}));

// tool 실행
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  return handleToolCall(request.params.name, request.params.arguments ?? {});
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // stderr로 로그 (stdout은 JSON-RPC 전용)
  console.error('[SAC MCP Sidecar] Started — archive read-only integration');
}

main().catch((err) => {
  console.error('[SAC MCP Sidecar] Fatal error:', err);
  process.exit(1);
});
