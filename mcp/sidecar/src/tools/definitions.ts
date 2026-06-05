// MCP Tool 정의 — Phase 1 Stub
// 실제 inputSchema는 Cursor Sprint 2에서 확정

export const toolDefinitions = [
  {
    name: 'list_documents',
    description: '문서 목록 조회. 필터: project, type, status, limit, offset',
    inputSchema: {
      type: 'object',
      properties: {
        project: { type: 'string' },
        type: { type: 'string' },
        status: { type: 'string', enum: ['active', 'archived'] },
        limit: { type: 'number', default: 20 },
        offset: { type: 'number', default: 0 },
      },
    },
  },
  {
    name: 'get_document',
    description: '단일 문서 조회 (메타데이터 + 본문 Markdown)',
    inputSchema: {
      type: 'object',
      required: ['id'],
      properties: {
        id: { type: 'string', description: 'sac_id (UUID)' },
      },
    },
  },
  {
    name: 'create_document',
    description: '문서 생성. write token 필요.',
    inputSchema: {
      type: 'object',
      required: ['title', 'relative_dir', 'token', 'agent_id'],
      properties: {
        title: { type: 'string' },
        type: { type: 'string' },
        project: { type: 'string' },
        author: { type: 'string' },
        relative_dir: { type: 'string' },
        initial_content: { type: 'string', default: '' },
        tags: { type: 'array', items: { type: 'string' } },
        token: { type: 'string', description: 'write PermissionToken ID' },
        agent_id: { type: 'string' },
      },
    },
  },
  {
    name: 'update_document',
    description: '문서 수정. write token + baseRevision 필요. revision 불일치 시 CONFLICT 에러.',
    inputSchema: {
      type: 'object',
      required: ['id', 'base_revision', 'token', 'agent_id'],
      properties: {
        id: { type: 'string' },
        title: { type: 'string' },
        content: { type: 'string' },
        base_revision: { type: 'number' },
        token: { type: 'string' },
        agent_id: { type: 'string' },
      },
    },
  },
  {
    name: 'search_documents',
    description: 'FTS5 기반 전문 검색',
    inputSchema: {
      type: 'object',
      required: ['text'],
      properties: {
        text: { type: 'string' },
        type: { type: 'string' },
        project: { type: 'string' },
        limit: { type: 'number', default: 20 },
      },
    },
  },
  {
    name: 'move_document_to_trash',
    description: '문서 휴지통 이동. destructive token 필요.',
    inputSchema: {
      type: 'object',
      required: ['id', 'token', 'agent_id'],
      properties: {
        id: { type: 'string' },
        token: { type: 'string', description: 'destructive PermissionToken ID' },
        agent_id: { type: 'string' },
      },
    },
  },
  {
    name: 'restore_document_from_trash',
    description: '휴지통에서 문서 복원. write token 필요.',
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
  {
    name: 'get_settings',
    description: '앱 설정 조회 (읽기 전용)',
    inputSchema: {
      type: 'object',
      properties: {},
    },
  },
];
