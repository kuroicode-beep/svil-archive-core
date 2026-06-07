// search_panel.dart — FTS 검색 placeholder (Sprint 3)

import 'package:flutter/material.dart';

import '../../domain/services/search_service.dart';

class SearchPanel extends StatefulWidget {
  final SearchService searchService;
  final void Function(String documentId)? onOpenDocument;

  const SearchPanel({
    super.key,
    required this.searchService,
    this.onOpenDocument,
  });

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  final _controller = TextEditingController();
  List<SearchResult> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 검색을 실행한다.
  Future<void> _runSearch() async {
    setState(() => _loading = true);
    try {
      final results = await widget.searchService.search(
        SearchQuery(text: _controller.text, limit: 30),
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 실패: $e')),
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
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: '키워드 검색',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _runSearch(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loading ? null : _runSearch,
                child: const Text('검색'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? const Center(
                      child: Text(
                        '검색어를 입력하세요.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        final doc = result.document;
                        return ListTile(
                          title: Text(doc.title, style: const TextStyle(fontSize: 16)),
                          subtitle: Text(
                            '${doc.path}\n${result.highlight ?? ''}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () => widget.onOpenDocument?.call(doc.id),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
