// definitions.ts — MCP tool 정의 (Sprint 14 read-only + queue-gated writes)

export const toolDefinitions = [
  {
    name: 'get_workspace_status',
    description: 'SAC workspace 상태 (root, index, documentCount, source)',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'get_settings',
    description: 'SAC workspace/MCP/privacy 설정 요약 (민감값 masking)',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'list_documents',
    description: '문서 목록 조회. 필터: project, type/category, limit, offset',
    inputSchema: {
      type: 'object',
      properties: {
        project: { type: 'string' },
        type: { type: 'string' },
        category: { type: 'string' },
        limit: { type: 'number', default: 20 },
        offset: { type: 'number', default: 0 },
      },
    },
  },
  {
    name: 'get_document',
    description: '문서 metadata + preview (본문 전체 반환 금지)',
    inputSchema: {
      type: 'object',
      required: ['id'],
      properties: {
        id: { type: 'string', description: 'sac_id (UUID)' },
        include_full_body: { type: 'boolean', default: false },
      },
    },
  },
  {
    name: 'search_documents',
    description: '문서 검색 (SQLite FTS 우선, 없으면 markdown scan fallback)',
    inputSchema: {
      type: 'object',
      required: ['text'],
      properties: {
        text: { type: 'string' },
        type: { type: 'string' },
        category: { type: 'string' },
        project: { type: 'string' },
        limit: { type: 'number', default: 20 },
      },
    },
  },
  {
    name: 'create_document',
    description: '문서 생성 — Work Queue approval 필요',
    inputSchema: {
      type: 'object',
      required: ['title', 'relative_dir', 'token', 'agent_id'],
      properties: {
        title: { type: 'string' },
        relative_dir: { type: 'string' },
        token: { type: 'string' },
        agent_id: { type: 'string' },
      },
    },
  },
  {
    name: 'update_document',
    description: '문서 수정 — Work Queue approval 필요',
    inputSchema: {
      type: 'object',
      required: ['id', 'base_revision', 'token', 'agent_id'],
      properties: {
        id: { type: 'string' },
        base_revision: { type: 'number' },
        token: { type: 'string' },
        agent_id: { type: 'string' },
      },
    },
  },
  {
    name: 'move_document_to_trash',
    description: '문서 휴지통 이동 — Work Queue approval 필요',
    inputSchema: {
      type: 'object',
      required: ['id', 'token', 'agent_id'],
      properties: {
        id: { type: 'string' },
        token: { type: 'string' },
        agent_id: { type: 'string' },
      },
    },
  },
  {
    name: 'restore_document_from_trash',
    description: '휴지통 복원 — Work Queue approval 필요',
    inputSchema: {
      type: 'object',
      required: ['trash_item_id', 'token', 'agent_id'],
      properties: {
        trash_item_id: { type: 'string' },
        token: { type: 'string' },
        agent_id: { type: 'string' },
      },
    },
  },
];
