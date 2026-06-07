// trash_panel.dart — 휴지통 목록/복구 placeholder (Sprint 3)

import 'package:flutter/material.dart';

import '../../domain/models/sync_state.dart';
import '../../domain/services/trash_service.dart';

class TrashPanel extends StatefulWidget {
  final TrashService trashService;
  final Future<void> Function(String trashItemId) onRestore;
  final Future<void> Function(String trashItemId) onDeletePermanently;

  const TrashPanel({
    super.key,
    required this.trashService,
    required this.onRestore,
    required this.onDeletePermanently,
  });

  @override
  State<TrashPanel> createState() => _TrashPanelState();
}

class _TrashPanelState extends State<TrashPanel> {
  List<TrashItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// 휴지통 목록을 새로고침한다.
  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final items = await widget.trashService.listTrashItems();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('휴지통 로드 실패: $e')),
        );
      }
    }
  }

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
                '휴지통',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(onPressed: _refresh, child: const Text('새로고침')),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(
                      child: Text(
                        '휴지통이 비어 있습니다.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          title: Text(
                            item.originalPath,
                            style: const TextStyle(fontSize: 16),
                          ),
                          subtitle: Text(
                            '삭제: ${item.trashedAt}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  await widget.onRestore(item.id);
                                  await _refresh();
                                },
                                child: const Text('복구'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await widget.onDeletePermanently(item.id);
                                  await _refresh();
                                },
                                child: const Text('완전삭제'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
