// mcp_bridge_status_service_impl.dart — MCP bridge 상태 및 queue 연동 구현

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/work_queue.dart';
import '../../domain/services/mcp_bridge_status_service.dart';
import '../../domain/services/mcp_tool_registry_service.dart';
import '../../domain/services/work_queue_service.dart';
import '../../domain/utils/mcp_sidecar_path_resolver.dart';

class McpBridgeStatusServiceImpl implements McpBridgeStatusService {
  final McpToolRegistryService _toolRegistry;
  final WorkQueueService _workQueue;
  final McpSidecarPathResolution sidecarResolution;

  McpBridgeStatusServiceImpl({
    required McpToolRegistryService toolRegistry,
    required WorkQueueService workQueue,
    McpSidecarPathResolution? sidecarResolution,
    String? sidecarDistPath,
  })  : _toolRegistry = toolRegistry,
        _workQueue = workQueue,
        sidecarResolution = sidecarResolution ??
            McpSidecarPathResolution(
              distPath: sidecarDistPath,
              source: sidecarDistPath == null
                  ? McpSidecarPathSource.notFound
                  : McpSidecarPathSource.devFallback,
            );

  @override
  Future<McpBridgeStatus> checkStatus() async {
    final dist = sidecarResolution.distPath;
    if (dist == null) {
      return const McpBridgeStatus(
        state: McpBridgeConnectionState.offline,
        label: 'sidecar 빌드 없음',
        localOnly: true,
      );
    }
    final file = File(p.join(dist, 'index.js'));
    if (await file.exists()) {
      return McpBridgeStatus(
        state: McpBridgeConnectionState.localReady,
        label: mcpSidecarStatusLabel(sidecarResolution),
        localOnly: true,
      );
    }
    return const McpBridgeStatus(
      state: McpBridgeConnectionState.offline,
      label: 'sidecar 빌드 없음',
      localOnly: true,
    );
  }

  @override
  Future<WorkQueueTicket> enqueueToolRequest(McpToolRequest request) async {
    final enabled = await _toolRegistry.isToolEnabled(request.toolName);
    if (!enabled) {
      throw StateError('MCP tool is disabled: ${request.toolName}');
    }

    final tools = await _toolRegistry.listTools();
    final tool = tools.firstWhere(
      (t) => t.toolName == request.toolName,
      orElse: () => throw StateError('Unknown MCP tool: ${request.toolName}'),
    );

    return _workQueue.createTicket(
      CreateWorkQueueTicketInput(
        actor: request.actor,
        requestedAction: request.toolName,
        targetType: request.targetType ?? 'document',
        targetId: request.targetId,
        targetPath: request.targetPath,
        permissionLevel: tool.permissionLevel,
        baseRevision: request.baseRevision,
        permissionTokenId: request.permissionTokenId,
        reason: 'MCP tool request queued (no direct execution)',
      ),
    );
  }
}
