// footer_bar.dart — 하단 푸터 (Workspace, sync 상태, 고대비 토글)

import 'package:flutter/material.dart';

const double _kFooterHeight = 50.0;

class FooterBar extends StatefulWidget {
  final String? workspaceName;
  final String? workspacePath;
  final String? syncStatus;

  const FooterBar({
    super.key,
    this.workspaceName,
    this.workspacePath,
    this.syncStatus,
  });

  @override
  State<FooterBar> createState() => _FooterBarState();
}

class _FooterBarState extends State<FooterBar> {
  bool _highContrast = false;

  @override
  Widget build(BuildContext context) {
    final workspaceLabel = widget.workspaceName ?? '—';
    final pathLabel = widget.workspacePath ?? '—';
    final syncLabel = widget.syncStatus ?? '—';

    return Container(
      height: _kFooterHeight,
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
          Text('sync: $syncLabel', style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 16),
          const Text('고대비', style: TextStyle(fontSize: 13)),
          Semantics(
            label: '고대비 모드',
            toggled: _highContrast,
            child: Switch(
              value: _highContrast,
              onChanged: (val) {
                setState(() => _highContrast = val);
              },
            ),
          ),
        ],
      ),
    );
  }
}
