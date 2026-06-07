// personal_archive_panel.dart — 개인 아카이브 화면 (Sprint 5)

import 'package:flutter/material.dart';

import '../../domain/models/personal_archive.dart';
import '../../domain/services/journal_comment_service.dart';
import '../../domain/services/personal_archive_service.dart';

class PersonalArchivePanel extends StatefulWidget {
  final PersonalArchiveService personalArchiveService;
  final JournalCommentService journalCommentService;

  const PersonalArchivePanel({
    super.key,
    required this.personalArchiveService,
    required this.journalCommentService,
  });

  @override
  State<PersonalArchivePanel> createState() => _PersonalArchivePanelState();
}

class _PersonalArchivePanelState extends State<PersonalArchivePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PersonalArchiveItem> _items = [];
  List<JournalComment> _journals = [];
  PersonalArchiveItem? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 데이터를 다시 로드한다.
  Future<void> _refresh() async {
    setState(() => _loading = true);
    final items = await widget.personalArchiveService.listItems();
    final journals = await widget.journalCommentService.listComments();
    if (!mounted) return;
    setState(() {
      _items = items;
      _journals = journals;
      _loading = false;
    });
  }

  /// 수동 항목 추가 다이얼로그를 연다.
  Future<void> _addManualItem(String itemType) async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$itemType 항목 추가'),
        content: SizedBox(
          width: 400,
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
                maxLines: 4,
                decoration: const InputDecoration(labelText: '내용'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    await widget.personalArchiveService.createManualItem(
      CreatePersonalArchiveItemInput(
        itemType: itemType,
        title: titleController.text.trim(),
        content: contentController.text.trim(),
      ),
    );
    await _refresh();
  }

  /// 선택 항목을 삭제한다.
  Future<void> _deleteSelected() async {
    final item = _selected;
    if (item == null) return;
    await widget.personalArchiveService.deleteItem(item.id);
    setState(() => _selected = null);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final profileCount = _items.where((i) => i.itemType == 'profile').length;
    final approvedCount = _items.where((i) => i.itemType == 'approved').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('개인 아카이브', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _SummaryChip(label: '전체', count: _items.length),
                  _SummaryChip(label: '프로필', count: profileCount),
                  _SummaryChip(label: '승인된 정보', count: approvedCount),
                  _SummaryChip(label: '일지', count: _journals.length),
                ],
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '프로필'),
            Tab(text: '승인된 정보'),
            Tab(text: '일지 코멘트'),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildItemList('profile'),
                    _buildItemList('approved'),
                    _buildJournalList(),
                  ],
                ),
        ),
        if (_selected != null)
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selected!.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (_selected!.sourcePath != null)
                  Text('출처: ${_selected!.sourcePath}', style: const TextStyle(fontSize: 14)),
                Text(_selected!.content, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _deleteSelected,
                    child: const Text('삭제'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// itemType별 리스트를 구성한다.
  Widget _buildItemList(String itemType) {
    final filtered = _items.where((i) => i.itemType == itemType).toList();
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _addManualItem(itemType),
                icon: const Icon(Icons.add),
                label: const Text('새 항목'),
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('항목이 없습니다.', style: TextStyle(fontSize: 16)))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return ListTile(
                      selected: _selected?.id == item.id,
                      title: Text(item.title, style: const TextStyle(fontSize: 16)),
                      subtitle: Text(
                        '${item.itemType} · ${item.status.name}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () => setState(() => _selected = item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 일지 코멘트 리스트를 구성한다.
  Widget _buildJournalList() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await widget.journalCommentService.createComment(
                    const CreateJournalCommentInput(
                      title: '새 일지',
                      content: '오늘의 기록',
                      mood: 'neutral',
                    ),
                  );
                  await _refresh();
                },
                icon: const Icon(Icons.add),
                label: const Text('새 일지'),
              ),
            ),
          ),
        ),
        Expanded(
          child: _journals.isEmpty
              ? const Center(child: Text('일지가 없습니다.', style: TextStyle(fontSize: 16)))
              : ListView.builder(
                  itemCount: _journals.length,
                  itemBuilder: (context, index) {
                    final journal = _journals[index];
                    return ListTile(
                      title: Text(journal.title, style: const TextStyle(fontSize: 16)),
                      subtitle: Text(
                        '${journal.mood ?? "—"} · ${journal.tags.join(", ")}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;

  const _SummaryChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $count', style: const TextStyle(fontSize: 14)),
    );
  }
}
