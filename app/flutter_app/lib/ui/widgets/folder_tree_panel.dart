// folder_tree_panel.dart — 카테고리 기준 폴더 트리 사이드바

import 'package:flutter/material.dart';

import '../../domain/models/document.dart';
import '../../domain/models/sync_state.dart';
import '../../data/platform/path_adapter.dart'
    show categoryFromRelativePath, kAllowedDocumentCategories;
import 'sync_status_badge.dart';

class FolderTreeNode {
  final String id;
  final String label;
  final DocumentMetadata? document;
  final List<FolderTreeNode> children;
  final bool isCategory;

  const FolderTreeNode({
    required this.id,
    required this.label,
    this.document,
    this.children = const [],
    this.isCategory = false,
  });
}

/// 문서 목록으로 카테고리 폴더 트리를 구성한다.
List<FolderTreeNode> buildFolderTree(List<DocumentMetadata> documents) {
  final grouped = <String, List<DocumentMetadata>>{};
  for (final doc in documents) {
    // category 단일 source = relative path (DB type과 불일치 방지)
    final category = categoryFromRelativePath(doc.path);
    grouped.putIfAbsent(category, () => []).add(doc);
  }

  final categories = kAllowedDocumentCategories.toList()
    ..sort()
    ..addAll(
      grouped.keys.where((key) => !kAllowedDocumentCategories.contains(key)),
    );

  return categories
      .where((category) => grouped.containsKey(category))
      .map((category) {
        final docs = grouped[category]!..sort((a, b) => a.title.compareTo(b.title));
        return FolderTreeNode(
          id: 'cat_$category',
          label: category,
          isCategory: true,
          children: docs
              .map(
                (doc) => FolderTreeNode(
                  id: doc.id,
                  label: doc.title,
                  document: doc,
                ),
              )
              .toList(),
        );
      })
      .toList();
}

class FolderTreePanel extends StatefulWidget {
  final List<DocumentMetadata> documents;
  final Map<String, SyncState> syncStates;
  final String? selectedId;
  final ValueChanged<DocumentMetadata> onSelect;
  final VoidCallback onCreateDocument;

  const FolderTreePanel({
    super.key,
    required this.documents,
    required this.syncStates,
    required this.selectedId,
    required this.onSelect,
    required this.onCreateDocument,
  });

  @override
  State<FolderTreePanel> createState() => _FolderTreePanelState();
}

class _FolderTreePanelState extends State<FolderTreePanel> {
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _expandAllCategories();
  }

  @override
  void didUpdateWidget(covariant FolderTreePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documents.length != widget.documents.length) {
      _expandAllCategories();
    }
  }

  /// 모든 카테고리 노드를 펼친다.
  void _expandAllCategories() {
    for (final node in buildFolderTree(widget.documents)) {
      _expanded.add(node.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tree = buildFolderTree(widget.documents);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '폴더 트리',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: '새 문서',
                icon: const Icon(Icons.add),
                onPressed: widget.onCreateDocument,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: tree.isEmpty
              ? const Center(
                  child: Text(
                    '문서가 없습니다.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView(
                  children: [
                    for (final node in tree) _buildNode(node, depth: 0),
                  ],
                ),
        ),
      ],
    );
  }

  /// 트리 노드 한 줄을 렌더링한다.
  Widget _buildNode(FolderTreeNode node, {required int depth}) {
    if (node.isCategory) {
      final expanded = _expanded.contains(node.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.only(left: 12.0 + depth * 12, right: 8),
            leading: Icon(
              expanded ? Icons.folder_open : Icons.folder,
              size: 20,
            ),
            title: Text(node.label, style: const TextStyle(fontSize: 16)),
            trailing: Text(
              '${node.children.length}',
              style: const TextStyle(fontSize: 13),
            ),
            onTap: () {
              setState(() {
                if (expanded) {
                  _expanded.remove(node.id);
                } else {
                  _expanded.add(node.id);
                }
              });
            },
          ),
          if (expanded)
            for (final child in node.children) _buildNode(child, depth: depth + 1),
        ],
      );
    }

    final doc = node.document!;
    final selected = doc.id == widget.selectedId;
    final sync = widget.syncStates[doc.id];
    return ListTile(
      dense: true,
      selected: selected,
      contentPadding: EdgeInsets.only(left: 12.0 + depth * 12, right: 8),
      leading: SyncStatusBadge(
        status: sync?.status ?? SyncStatus.clean,
        compact: true,
      ),
      title: Text(
        node.label,
        style: const TextStyle(fontSize: 16),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        doc.path,
        style: const TextStyle(fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => widget.onSelect(doc),
    );
  }
}
