// LeftSidebar: 좌측 사이드바 placeholder — 폴더 트리 + 메인 메뉴

import 'package:flutter/material.dart';

class LeftSidebar extends StatelessWidget {
  const LeftSidebar({super.key});

  static const _menuItems = [
    (Icons.dashboard, '대시보드'),
    (Icons.folder_open, '문서 아카이브'),
    (Icons.hub, 'AI 협업 프로토콜'),
    (Icons.person, '개인 아카이브'),
    (Icons.search, '검색'),
    (Icons.delete_outline, '휴지통'),
    (Icons.queue, '작업큐 / 티켓'),
    (Icons.electrical_services, 'MCP / AI 도구'),
    (Icons.security, '개인정보 보호'),
    (Icons.settings, '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'SAC',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: _menuItems.map((item) {
                return ListTile(
                  leading: Icon(item.$1, size: 20),
                  title: Text(item.$2, style: const TextStyle(fontSize: 16)),
                  minVerticalPadding: 15, // 터치 타겟 50px 기준
                  onTap: () {
                    // TODO(Cursor): 화면 라우팅 연결
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
