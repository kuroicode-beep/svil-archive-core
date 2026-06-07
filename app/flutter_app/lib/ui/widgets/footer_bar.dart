// footer_bar.dart — 하단 푸터 (Workspace, sync 상태, 고대비 토글)

import 'package:flutter/material.dart';

import '../../domain/models/sync_state.dart';
import 'sync_status_badge.dart';

const double kFooterHeight = 50.0;

class FooterBar extends StatelessWidget {
  final String? workspaceName;
  final String? workspacePath;
  final SyncState? syncState;
  final bool highContrastEnabled;
  final ValueChanged<bool>? onHighContrastChanged;

  const FooterBar({
    super.key,
    this.workspaceName,
    this.workspacePath,
    this.syncState,
    this.highContrastEnabled = false,
    this.onHighContrastChanged,
  });

  @override
  Widget build(BuildContext context) {
    final workspaceLabel = workspaceName ?? '—';
    final pathLabel = workspacePath ?? '—';

    return Container(
      height: kFooterHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.circle, size: 10, color: Colors.grey),
          const SizedBox(width: 6),
          const Text('MCP: 대기', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Workspace: $workspaceLabel ($pathLabel)',
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (syncState != null) ...[
            SyncStatusBadge(status: syncState!.status, compact: true),
            const SizedBox(width: 6),
            Text(
              SyncStatusBadge.labelFor(syncState!.status),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 16),
          ],
          const Text('고대비', style: TextStyle(fontSize: 13)),
          Semantics(
            label: '고대비 모드',
            toggled: highContrastEnabled,
            child: Switch(
              value: highContrastEnabled,
              onChanged: onHighContrastChanged,
            ),
          ),
        ],
      ),
    );
  }
}
