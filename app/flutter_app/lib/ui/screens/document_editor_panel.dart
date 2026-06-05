// document_editor_panel.dart — 문서 편집 placeholder (Sprint 2)

import 'package:flutter/material.dart';

import '../../domain/models/document.dart';
import '../../domain/models/sync_state.dart';

class DocumentEditorPanel extends StatefulWidget {
  final Document? document;
  final SyncState? syncState;
  final Future<void> Function(String title, String body) onSave;

  const DocumentEditorPanel({
    super.key,
    required this.document,
    required this.syncState,
    required this.onSave,
  });

  @override
  State<DocumentEditorPanel> createState() => _DocumentEditorPanelState();
}

class _DocumentEditorPanelState extends State<DocumentEditorPanel> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _saving = false;

  @override
  void didUpdateWidget(covariant DocumentEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document?.metadata.id != oldWidget.document?.metadata.id) {
      _loadDocument();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  /// 현재 문서 내용을 입력 필드에 반영한다.
  void _loadDocument() {
    final doc = widget.document;
    if (doc == null) {
      _titleController.clear();
      _bodyController.clear();
      return;
    }
    _titleController.text = doc.metadata.title;
    _bodyController.text = doc.content?.rawMarkdown ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  /// 문서 저장을 실행한다.
  Future<void> _handleSave() async {
    if (widget.document == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _titleController.text.trim(),
        _bodyController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('문서가 저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.document == null) {
      return const Center(
        child: Text(
          '문서를 선택하거나 새로 만드세요.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final status = widget.syncState?.status.name ?? 'clean';
    final revision = widget.syncState?.revision ?? widget.document!.metadata.revision;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: '제목',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('rev $revision', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Chip(label: Text(status, style: const TextStyle(fontSize: 13))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saving ? null : _handleSave,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('저장'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _bodyController,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                labelText: 'Markdown 본문',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
