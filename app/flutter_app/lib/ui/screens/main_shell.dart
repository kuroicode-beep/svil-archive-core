// main_shell.dart — 3패널 레이아웃 + 문서 목록/편집 (Sprint 2)

import 'package:flutter/material.dart';

import '../../application/sac_container.dart';
import '../../domain/models/document.dart';
import '../../domain/models/sync_state.dart';
import '../../domain/services/archive_service.dart';
import '../widgets/footer_bar.dart';
import '../widgets/left_sidebar.dart';
import '../widgets/right_context_panel.dart';
import 'document_archive_panel.dart';
import 'document_editor_panel.dart';

class MainShell extends StatefulWidget {
  final SacContainer container;

  const MainShell({super.key, required this.container});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  List<DocumentMetadata> _documents = [];
  Document? _selectedDocument;
  SyncState? _selectedSyncState;
  bool _loading = true;

  ArchiveService get _archive => widget.container.archiveService;

  @override
  void initState() {
    super.initState();
    _refreshDocuments();
  }

  /// 문서 목록을 다시 로드한다.
  Future<void> _refreshDocuments() async {
    setState(() => _loading = true);
    try {
      final docs = await _archive.listDocuments();
      if (!mounted) return;
      setState(() {
        _documents = docs;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('문서 목록 로드 실패: $e')),
        );
      }
    }
  }

  /// 문서를 선택하고 내용을 로드한다.
  Future<void> _selectDocument(DocumentMetadata metadata) async {
    final doc = await _archive.getDocumentWithContent(metadata.id);
    final sync = await widget.container.syncService.getSyncState(metadata.id);
    if (!mounted) return;
    setState(() {
      _selectedDocument = doc;
      _selectedSyncState = sync;
    });
  }

  /// 샘플 문서를 생성한다.
  Future<void> _createSampleDocument() async {
    final count = _documents.length + 1;
    final doc = await _archive.createDocument(
      CreateDocumentInput(
        title: 'Sample_$count',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# Sample Document $count\n\nSAC Sprint 2 vertical slice.',
        author: 'user',
      ),
    );
    await _refreshDocuments();
    await _selectDocument(doc.metadata);
  }

  /// 문서 수정 내용을 저장한다.
  Future<void> _saveDocument(String title, String body) async {
    final current = _selectedDocument;
    if (current == null) return;
    final sync = _selectedSyncState ??
        await widget.container.syncService.getSyncState(current.metadata.id);

    final updated = await _archive.updateDocument(
      UpdateDocumentInput(
        id: current.metadata.id,
        title: title,
        content: body,
        author: 'user',
        baseRevision: sync.revision,
      ),
    );
    final newSync =
        await widget.container.syncService.getSyncState(updated.metadata.id);
    if (!mounted) return;
    setState(() {
      _selectedDocument = updated;
      _selectedSyncState = newSync;
    });
    await _refreshDocuments();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.container.activeWorkspace;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 240, child: LeftSidebar()),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 280,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : DocumentArchivePanel(
                          documents: _documents,
                          selectedId: _selectedDocument?.metadata.id,
                          onSelect: _selectDocument,
                          onCreateSample: _createSampleDocument,
                        ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: DocumentEditorPanel(
                    document: _selectedDocument,
                    syncState: _selectedSyncState,
                    onSave: _saveDocument,
                  ),
                ),
                const VerticalDivider(width: 1),
                const SizedBox(width: 280, child: RightContextPanel()),
              ],
            ),
          ),
          const Divider(height: 1),
          FooterBar(
            workspaceName: workspace?.name,
            workspacePath: workspace?.rootPath,
            syncStatus: _selectedSyncState?.status.name,
          ),
        ],
      ),
    );
  }
}
