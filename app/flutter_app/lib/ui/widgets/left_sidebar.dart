// left_sidebar.dart — 좌측 사이드바 + 화면 전환

import 'package:flutter/material.dart';

enum SacSection { archive, search, trash, personalArchive, extractionQueue }

class LeftSidebar extends StatelessWidget {
  final SacSection selected;
  final ValueChanged<SacSection> onSectionChanged;

  const LeftSidebar({
    super.key,
    required this.selected,
    required this.onSectionChanged,
  });

  static const _items = <(SacSection, IconData, String)>[
    (SacSection.archive, Icons.folder_open, '문서 아카이브'),
    (SacSection.personalArchive, Icons.person_outline, '개인 아카이브'),
    (SacSection.extractionQueue, Icons.pending_actions, '추출 대기열'),
    (SacSection.search, Icons.search, '검색'),
    (SacSection.trash, Icons.delete_outline, '휴지통'),
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
              children: _items.map((item) {
                final isSelected = selected == item.$1;
                return ListTile(
                  selected: isSelected,
                  leading: Icon(item.$2, size: 20),
                  title: Text(item.$3, style: const TextStyle(fontSize: 16)),
                  minVerticalPadding: 15,
                  onTap: () => onSectionChanged(item.$1),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
