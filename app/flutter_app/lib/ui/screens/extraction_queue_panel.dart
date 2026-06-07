// extraction_queue_panel.dart — 추출 대기열 화면 (Sprint 5)

import 'package:flutter/material.dart';

import '../../domain/models/personal_archive.dart';
import '../../domain/services/extraction_queue_service.dart';

class ExtractionQueuePanel extends StatefulWidget {
  final ExtractionQueueService extractionQueueService;

  const ExtractionQueuePanel({
    super.key,
    required this.extractionQueueService,
  });

  @override
  State<ExtractionQueuePanel> createState() => _ExtractionQueuePanelState();
}

class _ExtractionQueuePanelState extends State<ExtractionQueuePanel> {
  List<ExtractionCandidate> _pending = [];
  List<ExtractionCandidate> _all = [];
  ExtractionCandidate? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// 대기열 데이터를 다시 로드한다.
  Future<void> _refresh() async {
    setState(() => _loading = true);
    final pending = await widget.extractionQueueService.listPendingCandidates();
    final all = await widget.extractionQueueService.listAllCandidates();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _all = all;
      _loading = false;
    });
  }

  /// 후보를 승인한다.
  Future<void> _approve(String id) async {
    await widget.extractionQueueService.approveCandidate(id);
    setState(() => _selected = null);
    await _refresh();
  }

  /// 후보를 거절한다.
  Future<void> _reject(String id) async {
    await widget.extractionQueueService.rejectCandidate(id);
    setState(() => _selected = null);
    await _refresh();
  }

  /// 수정 후 승인 다이얼로그를 연다.
  Future<void> _editAndApprove(ExtractionCandidate candidate) async {
    final titleController = TextEditingController(text: candidate.candidateTitle);
    final contentController = TextEditingController(text: candidate.candidateContent);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('수정 후 승인'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '제목'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '내용'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('수정 후 승인'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    await widget.extractionQueueService.editAndApproveCandidate(
      EditExtractionCandidateInput(
        candidateId: candidate.id,
        title: titleController.text.trim(),
        content: contentController.text.trim(),
      ),
    );
    setState(() => _selected = null);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final approvedCount = _all.where((c) => c.status == ExtractionQueueStatus.approved || c.status == ExtractionQueueStatus.editedApproved).length;
    final rejectedCount = _all.where((c) => c.status == ExtractionQueueStatus.rejected).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('추출 대기열', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  Chip(label: Text('승인 대기: ${_pending.length}', style: const TextStyle(fontSize: 14))),
                  Chip(label: Text('승인됨: $approvedCount', style: const TextStyle(fontSize: 14))),
                  Chip(label: Text('거절됨: $rejectedCount', style: const TextStyle(fontSize: 14))),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _pending.isEmpty
                  ? const Center(child: Text('승인 대기 후보가 없습니다.', style: TextStyle(fontSize: 16)))
                  : Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ListView.builder(
                            itemCount: _pending.length,
                            itemBuilder: (context, index) {
                              final item = _pending[index];
                              return ListTile(
                                selected: _selected?.id == item.id,
                                title: Text(item.candidateTitle, style: const TextStyle(fontSize: 16)),
                                subtitle: Text(
                                  '${item.candidateType} · 상태: ${item.status.name}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                onTap: () => setState(() => _selected = item),
                              );
                            },
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          flex: 3,
                          child: _selected == null
                              ? const Center(child: Text('후보를 선택하세요.', style: TextStyle(fontSize: 16)))
                              : Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(_selected!.candidateTitle,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      if (_selected!.sourcePath != null)
                                        Text('출처: ${_selected!.sourcePath}', style: const TextStyle(fontSize: 14)),
                                      Text('신뢰도: ${_selected!.confidence ?? 0}',
                                          style: const TextStyle(fontSize: 14)),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: Text(_selected!.candidateContent,
                                              style: const TextStyle(fontSize: 16)),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 50,
                                        child: ElevatedButton(
                                          onPressed: () => _approve(_selected!.id),
                                          child: const Text('승인'),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 50,
                                        child: OutlinedButton(
                                          onPressed: () => _editAndApprove(_selected!),
                                          child: const Text('수정 후 승인'),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 50,
                                        child: OutlinedButton(
                                          onPressed: () => _reject(_selected!.id),
                                          child: const Text('거절'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}
