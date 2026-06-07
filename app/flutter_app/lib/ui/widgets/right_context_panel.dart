// right_context_panel.dart — 문서 메타데이터 편집 + TTS stub

import 'package:flutter/material.dart';

import '../../data/platform/path_adapter.dart';
import '../../domain/models/document.dart';
import '../../domain/models/sync_state.dart';
import 'sync_status_badge.dart';

class RightContextPanel extends StatefulWidget {
  final Document? document;
  final SyncState? syncState;
  final Future<void> Function({
    required String type,
    required String project,
    required List<String> tags,
    required String summary,
  })? onSaveMetadata;

  const RightContextPanel({
    super.key,
    required this.document,
    required this.syncState,
    this.onSaveMetadata,
  });

  @override
  State<RightContextPanel> createState() => _RightContextPanelState();
}

class _RightContextPanelState extends State<RightContextPanel> {
  final _projectController = TextEditingController();
  final _tagsController = TextEditingController();
  final _summaryController = TextEditingController();
  String? _selectedType;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant RightContextPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document?.metadata.id != oldWidget.document?.metadata.id) {
      _loadMetadata();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  /// 선택 문서 메타데이터를 입력 필드에 반영한다.
  void _loadMetadata() {
    final metadata = widget.document?.metadata;
    if (metadata == null) {
      _projectController.clear();
      _tagsController.clear();
      _summaryController.clear();
      _selectedType = null;
      return;
    }
    _projectController.text = metadata.project ?? '';
    _tagsController.text = metadata.tags.join(', ');
    _summaryController.text = metadata.summary ?? '';
    _selectedType = metadata.type;
  }

  @override
  void dispose() {
    _projectController.dispose();
    _tagsController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  /// 메타데이터 저장을 실행한다.
  Future<void> _handleSave() async {
    final doc = widget.document;
    final onSave = widget.onSaveMetadata;
    if (doc == null || onSave == null || _saving) return;

    setState(() => _saving = true);
    try {
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      await onSave(
        type: _selectedType ?? doc.metadata.type ?? 'Dev',
        project: _projectController.text.trim(),
        tags: tags,
        summary: _summaryController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메타데이터가 저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메타데이터 저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    if (doc == null) {
      return Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.all(16),
        child: const Text(
          '문서를 선택하면 메타데이터를 편집할 수 있습니다.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final metadata = doc.metadata;
    final sync = widget.syncState;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('메타데이터', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (sync != null) SyncStatusBadge(status: sync.status),
          const SizedBox(height: 12),
          Text('경로', style: Theme.of(context).textTheme.labelLarge),
          Text(metadata.path, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: const InputDecoration(
              labelText: '카테고리',
              border: OutlineInputBorder(),
            ),
            items: kAllowedDocumentCategories
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedType = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _projectController,
            decoration: const InputDecoration(
              labelText: '프로젝트',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: '태그 (쉼표 구분)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _summaryController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '요약',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saving ? null : _handleSave,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('메타데이터 저장'),
          ),
          const Spacer(),
          Text('TTS', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                iconSize: 30,
                tooltip: '읽기 시작',
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.pause),
                iconSize: 30,
                tooltip: '일시정지',
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                iconSize: 30,
                tooltip: '정지',
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
