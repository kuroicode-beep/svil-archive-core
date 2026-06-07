// footer_bar.dart — 하단 푸터 (Workspace, sync 상태, MCP, 고대비 토글)

import 'package:flutter/material.dart';

import '../../domain/models/sync_state.dart';
import '../../domain/services/mcp_bridge_status_service.dart';
import 'sync_status_badge.dart';

const double kFooterHeight = 50.0;

class FooterBar extends StatefulWidget {
  final String? workspaceName;
  final String? workspacePath;
  final SyncState? syncState;
  final McpBridgeStatusService? mcpBridgeService;
  final bool highContrastEnabled;
  final ValueChanged<bool>? onHighContrastChanged;

  const FooterBar({
    super.key,
    this.workspaceName,
    this.workspacePath,
    this.syncState,
    this.mcpBridgeService,
    this.highContrastEnabled = false,
    this.onHighContrastChanged,
  });

  @override
  State<FooterBar> createState() => _FooterBarState();
}

class _FooterBarState extends State<FooterBar> {
  String _mcpLabel = 'MCP: 로딩';

  @override
  void initState() {
    super.initState();
    _loadMcpStatus();
  }

  @override
  void didUpdateWidget(covariant FooterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mcpBridgeService != widget.mcpBridgeService) {
      _loadMcpStatus();
    }
  }

  /// MCP bridge 상태를 로드한다.
  Future<void> _loadMcpStatus() async {
    final service = widget.mcpBridgeService;
    if (service == null) {
      if (mounted) setState(() => _mcpLabel = 'MCP: 대기');
      return;
    }
    try {
      final status = await service.checkStatus();
      if (!mounted) return;
      setState(() => _mcpLabel = 'MCP: ${status.label}');
    } catch (_) {
      if (mounted) setState(() => _mcpLabel = 'MCP: 오류');
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspaceLabel = widget.workspaceName ?? '—';
    final pathLabel = widget.workspacePath ?? '—';

    return Container(
      height: kFooterHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.circle, size: 10, color: Colors.grey),
          const SizedBox(width: 6),
          Text(_mcpLabel, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Workspace: $workspaceLabel ($pathLabel)',
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.syncState != null) ...[
            SyncStatusBadge(status: widget.syncState!.status, compact: true),
            const SizedBox(width: 6),
            Text(
              SyncStatusBadge.labelFor(widget.syncState!.status),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 16),
          ],
          const Text('고대비', style: TextStyle(fontSize: 13)),
          Semantics(
            label: '고대비 모드',
            toggled: widget.highContrastEnabled,
            child: Switch(
              value: widget.highContrastEnabled,
              onChanged: widget.onHighContrastChanged,
            ),
          ),
        ],
      ),
    );
  }
}
