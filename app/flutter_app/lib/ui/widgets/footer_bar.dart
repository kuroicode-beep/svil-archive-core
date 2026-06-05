// FooterBar: 하단 푸터 — MCP 상태, Workspace명, 고대비 토글 고정 배치

import 'package:flutter/material.dart';

class FooterBar extends StatefulWidget {
  const FooterBar({super.key});

  @override
  State<FooterBar> createState() => _FooterBarState();
}

class _FooterBarState extends State<FooterBar> {
  bool _highContrast = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          // MCP 상태
          const Icon(Icons.circle, size: 10, color: Colors.grey),
          const SizedBox(width: 6),
          const Text('MCP: 대기', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 16),
          // Workspace명
          const Text('Workspace: —', style: TextStyle(fontSize: 13)),
          const Spacer(),
          // 고대비 토글 (터치 타겟 50px 이상 보장)
          const Text('고대비', style: TextStyle(fontSize: 13)),
          SizedBox(
            height: 50,
            child: Switch(
              value: _highContrast,
              onChanged: (val) {
                setState(() => _highContrast = val);
                // TODO(Cursor): ThemeService.toggleHighContrast 연결
              },
            ),
          ),
        ],
      ),
    );
  }
}
