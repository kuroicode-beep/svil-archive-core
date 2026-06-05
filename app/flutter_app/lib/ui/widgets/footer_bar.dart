// FooterBar: 하단 푸터 — MCP 상태, Workspace명, 고대비 토글 고정 배치
// 접근성: 터치 타겟 50px 이상 — footer 높이를 50px로 맞춰 Switch clipping 방지

import 'package:flutter/material.dart';

// 접근성 기준 최소 터치 타겟 높이
const double _kFooterHeight = 50.0;

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
      // 50px: 접근성 기준 최소 터치 타겟 + Switch overflow 방지
      height: _kFooterHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // MCP 상태
          const Icon(Icons.circle, size: 10, color: Colors.grey),
          const SizedBox(width: 6),
          const Text('MCP: 대기', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 16),
          // Workspace명
          const Text('Workspace: —', style: TextStyle(fontSize: 13)),
          const Spacer(),
          // 고대비 토글 — Semantics로 접근성 레이블 명시
          const Text('고대비', style: TextStyle(fontSize: 13)),
          Semantics(
            label: '고대비 모드',
            toggled: _highContrast,
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
