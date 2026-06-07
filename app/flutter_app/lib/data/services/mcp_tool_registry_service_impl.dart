// mcp_tool_registry_service_impl.dart — MCP tool registry SQLite 구현

import 'package:sqflite/sqflite.dart';

import '../../domain/models/work_queue.dart';
import '../../domain/services/mcp_tool_registry_service.dart';
import '../db/database_service_impl.dart';

/// 기본 MCP tool 정의 (보수적 기본값: 모두 비활성).
const List<(String, PermissionLevel, String)> kDefaultMcpTools = [
  ('list_documents', PermissionLevel.read, '문서 목록 조회'),
  ('get_document', PermissionLevel.read, '단일 문서 조회'),
  ('search_documents', PermissionLevel.read, 'FTS 검색'),
  ('get_settings', PermissionLevel.read, '앱 설정 조회'),
  ('create_document', PermissionLevel.write, '문서 생성'),
  ('update_document', PermissionLevel.write, '문서 수정'),
  ('restore_document_from_trash', PermissionLevel.write, '휴지통 복원'),
  ('move_document_to_trash', PermissionLevel.destructive, '휴지통 이동 (파괴적)'),
];

class McpToolRegistryServiceImpl implements McpToolRegistryService {
  final DatabaseServiceImpl _databaseService;

  McpToolRegistryServiceImpl({required DatabaseServiceImpl databaseService})
      : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<void> ensureDefaultTools() async {
    final now = DateTime.now().toUtc().toIso8601String();
    for (final tool in kDefaultMcpTools) {
      final existing = await _db.query(
        'mcp_tool_settings',
        where: 'tool_name = ?',
        whereArgs: [tool.$1],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      await _db.insert('mcp_tool_settings', {
        'tool_name': tool.$1,
        'enabled': 0,
        'permission_level': tool.$2.name,
        'description': tool.$3,
        'updated_at': now,
      });
    }
  }

  @override
  Future<List<McpToolSetting>> listTools() async {
    await ensureDefaultTools();
    final rows = await _db.query('mcp_tool_settings', orderBy: 'tool_name ASC');
    return rows.map(_mapRow).toList();
  }

  @override
  Future<void> setToolEnabled(String toolName, bool enabled) async {
    await ensureDefaultTools();
    await _db.update(
      'mcp_tool_settings',
      {
        'enabled': enabled ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'tool_name = ?',
      whereArgs: [toolName],
    );
  }

  @override
  Future<bool> isToolEnabled(String toolName) async {
    await ensureDefaultTools();
    final rows = await _db.query(
      'mcp_tool_settings',
      where: 'tool_name = ?',
      whereArgs: [toolName],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['enabled'] as int? ?? 0) == 1;
  }

  /// DB row를 McpToolSetting으로 변환한다.
  McpToolSetting _mapRow(Map<String, Object?> row) {
    return McpToolSetting(
      toolName: row['tool_name'] as String,
      enabled: (row['enabled'] as int? ?? 0) == 1,
      permissionLevel: PermissionLevel.values.firstWhere(
        (p) => p.name == (row['permission_level'] as String? ?? 'read'),
        orElse: () => PermissionLevel.read,
      ),
      description: row['description'] as String? ?? '',
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }
}
