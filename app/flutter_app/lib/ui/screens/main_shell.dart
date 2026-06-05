// MainShell: 3패널 기본 레이아웃 placeholder
// 좌측 사이드바 | 중앙 메인 | 우측 컨텍스트 패널

import 'package:flutter/material.dart';
import '../widgets/left_sidebar.dart';
import '../widgets/right_context_panel.dart';
import '../widgets/footer_bar.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // 좌측 사이드바 (폴더 트리 + 메뉴)
                const SizedBox(width: 240, child: LeftSidebar()),
                const VerticalDivider(width: 1),
                // 중앙 메인 영역
                Expanded(
                  child: _MainContent(),
                ),
                const VerticalDivider(width: 1),
                // 우측 컨텍스트 패널
                const SizedBox(width: 280, child: RightContextPanel()),
              ],
            ),
          ),
          const Divider(height: 1),
          // 하단 푸터 (MCP 상태, Workspace, 고대비 토글)
          const FooterBar(),
        ],
      ),
    );
  }
}

class _MainContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Main Content Area\n(Placeholder — Cursor Sprint 2에서 구현)',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }
}
