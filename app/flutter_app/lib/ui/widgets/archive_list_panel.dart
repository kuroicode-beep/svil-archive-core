// archive_list_panel.dart — 문서 아카이브 목록 패널 (Sprint 16H-3)

import 'package:flutter/material.dart';

import '../../domain/models/document.dart';
import '../../domain/models/sync_state.dart';
import 'sync_status_badge.dart';

/// 문서 아카이브 목록 패널 상태.
enum ArchiveListPanelState { loading, empty, error, ready }

class ArchiveListPanel extends StatelessWidget {
  final ArchiveListPanelState state;
  final List<DocumentMetadata> documents;
  final Map<String, SyncState> syncStates;
  final String? selectedId;
  final String? errorMessage;
  final ValueChanged<DocumentMetadata> onSelect;
  final VoidCallback onCreateDocument;
  final VoidCallback onRefresh;

  const ArchiveListPanel({
    super.key,
    required this.state,
    required this.documents,
    required this.syncStates,
    required this.selectedId,
    this.errorMessage,
    required this.onSelect,
    required this.onCreateDocument,
    required this.onRefresh,
  });

  /// 고대비/다크에서도 읽히는 보조 텍스트 색을 반환한다.
  Color _mutedTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75);
  }

  /// 상태 안내 카드를 구성한다.
  Widget _statusCard(
    BuildContext context, {
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '문서 아카이브',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '목록 ${documents.length}건',
                        style: TextStyle(fontSize: 16, color: _mutedTextColor(context)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '목록 새로고침',
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
                ),
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: onCreateDocument,
                    icon: const Icon(Icons.add),
                    label: const Text('새 문서'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: switch (state) {
              ArchiveListPanelState.loading => _statusCard(
                  context,
                  title: '문서 목록을 불러오는 중입니다',
                  message: '잠시만 기다려 주세요.',
                ),
              ArchiveListPanelState.error => _statusCard(
                  context,
                  title: '문서 목록을 불러오지 못했습니다',
                  message: errorMessage ?? '알 수 없는 오류',
                  action: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: onRefresh,
                      child: const Text('다시 시도'),
                    ),
                  ),
                ),
              ArchiveListPanelState.empty => _statusCard(
                  context,
                  title: '등록된 문서가 없습니다',
                  message: '파일 Import에서 문서를 등록하세요.',
                  action: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: onCreateDocument,
                      child: const Text('샘플 문서 만들기'),
                    ),
                  ),
                ),
              ArchiveListPanelState.ready => ListView.builder(
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final doc = documents[index];
                    final selected = doc.id == selectedId;
                    final sync = syncStates[doc.id];
                    return ListTile(
                      selected: selected,
                      selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      title: Text(
                        doc.title,
                        style: TextStyle(
                          fontSize: 16,
                          color: onSurface,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        doc.path,
                        style: TextStyle(fontSize: 16, color: _mutedTextColor(context)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      leading: SyncStatusBadge(
                        status: sync?.status ?? SyncStatus.clean,
                        compact: true,
                      ),
                      onTap: () => onSelect(doc),
                    );
                  },
                ),
            },
          ),
        ],
      ),
    );
  }
}
