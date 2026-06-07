// document_archive_panel.dart — 문서 목록 placeholder (Sprint 2)

import 'package:flutter/material.dart';

import '../../domain/models/document.dart';

class DocumentArchivePanel extends StatelessWidget {
  final List<DocumentMetadata> documents;
  final String? selectedId;
  final ValueChanged<DocumentMetadata> onSelect;
  final VoidCallback onCreateSample;
  final Future<void> Function(String documentId)? onMoveToTrash;

  const DocumentArchivePanel({
    super.key,
    required this.documents,
    required this.selectedId,
    required this.onSelect,
    required this.onCreateSample,
    this.onMoveToTrash,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text(
                '문서 아카이브',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onCreateSample,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('새 문서'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: documents.isEmpty
              ? const Center(
                  child: Text(
                    '문서가 없습니다.\n새 문서를 만들어 보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final doc = documents[index];
                    final selected = doc.id == selectedId;
                    return ListTile(
                      selected: selected,
                      title: Text(doc.title, style: const TextStyle(fontSize: 16)),
                      subtitle: Text(
                        doc.path,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: onMoveToTrash == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: '휴지통으로 이동',
                              onPressed: () => onMoveToTrash!(doc.id),
                            ),
                      onTap: () => onSelect(doc),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
