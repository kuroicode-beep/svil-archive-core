// main_shell.dart — 3패널 레이아웃 + 폴더 트리/메타데이터 (Sprint 4)

import 'package:flutter/material.dart';

import '../../application/sac_container.dart';
import '../../domain/models/document.dart';
import '../../domain/models/sync_state.dart';
import '../../domain/services/archive_service.dart';
import '../widgets/folder_tree_panel.dart';
import '../widgets/footer_bar.dart';
import '../widgets/left_sidebar.dart';
import '../widgets/right_context_panel.dart';
import 'dashboard_screen.dart';
import 'document_editor_panel.dart';
import 'extraction_queue_panel.dart';
import 'personal_archive_panel.dart';
import 'work_queue_panel.dart';
import 'integrity_screen.dart';
import 'privacy_screen.dart';
import 'search_panel.dart';
import 'trash_panel.dart';

class MainShell extends StatefulWidget {
  final SacContainer container;

  const MainShell({super.key, required this.container});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  SacSection _section = SacSection.dashboard;
  List<DocumentMetadata> _documents = [];
  Map<String, SyncState> _syncStates = {};
  Document? _selectedDocument;
  SyncState? _selectedSyncState;
  bool _loading = true;

  ArchiveService get _archive => widget.container.archiveService;

  @override
  void initState() {
    super.initState();
    widget.container.onWorkspaceFileChanged = _handleExternalFileChange;
    _refreshDocuments();
  }

  @override
  void dispose() {
    widget.container.onWorkspaceFileChanged = null;
    super.dispose();
  }

  /// 외부 파일 변경 시 sync 상태를 갱신한다.
  Future<void> _handleExternalFileChange() async {
    await _refreshSyncStates();
    final selectedId = _selectedDocument?.metadata.id;
    if (selectedId != null) {
      final sync = await widget.container.syncService.getSyncState(selectedId);
      if (mounted) setState(() => _selectedSyncState = sync);
    }
  }

  /// 문서 목록과 sync 상태를 다시 로드한다.
  Future<void> _refreshDocuments() async {
    setState(() => _loading = true);
    try {
      final docs = await _archive.listDocuments();
      final syncStates = await widget.container.syncService.listSyncStates();
      if (!mounted) return;
      setState(() {
        _documents = docs;
        _syncStates = syncStates;
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

  /// sync 상태 맵만 갱신한다.
  Future<void> _refreshSyncStates() async {
    final syncStates = await widget.container.syncService.listSyncStates();
    if (mounted) setState(() => _syncStates = syncStates);
  }

  /// 문서를 선택하고 내용을 로드한다.
  Future<void> _selectDocument(DocumentMetadata metadata) async {
    final doc = await _archive.getDocumentWithContent(metadata.id);
    final sync = await widget.container.syncService.getSyncState(metadata.id);
    if (!mounted) return;
    setState(() {
      _section = SacSection.archive;
      _selectedDocument = doc;
      _selectedSyncState = sync;
    });
  }

  /// document id로 문서를 연다.
  Future<void> _openDocumentById(String documentId) async {
    final metadata = await _archive.getDocument(documentId);
    if (metadata != null) {
      await _selectDocument(metadata);
    }
  }

  /// 샘플 문서를 생성한다.
  Future<void> _createSampleDocument() async {
    final count = _documents.length + 1;
    final doc = await _archive.createDocument(
      CreateDocumentInput(
        title: 'Sample_$count',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# Sample Document $count\n\nSAC Sprint 4 metadata test.',
        author: 'user',
        tags: ['sprint4'],
        project: 'SAC',
      ),
    );
    await widget.container.indexingQueue?.flushForTest();
    await _refreshDocuments();
    await _selectDocument(doc.metadata);
  }

  /// 문서 본문/제목을 저장한다.
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
    await widget.container.indexingQueue?.flushForTest();
    final newSync =
        await widget.container.syncService.getSyncState(updated.metadata.id);
    if (!mounted) return;
    setState(() {
      _selectedDocument = updated;
      _selectedSyncState = newSync;
    });
    await _refreshDocuments();
  }

  /// 문서 메타데이터를 저장한다 (category는 경로 기준이므로 편집 불가).
  Future<void> _saveMetadata({
    required String project,
    required List<String> tags,
    required String summary,
  }) async {
    final current = _selectedDocument;
    if (current == null) return;
    final sync = _selectedSyncState ??
        await widget.container.syncService.getSyncState(current.metadata.id);

    final updated = await _archive.updateDocument(
      UpdateDocumentInput(
        id: current.metadata.id,
        project: project,
        tags: tags,
        summary: summary,
        author: 'user',
        baseRevision: sync.revision,
      ),
    );
    await widget.container.indexingQueue?.flushForTest();
    if (!mounted) return;
    setState(() => _selectedDocument = updated);
    await _refreshDocuments();
  }

  /// 문서를 휴지통으로 이동한다.
  Future<void> _moveToTrash(String documentId) async {
    await _archive.moveDocumentToTrash(documentId);
    await widget.container.indexingQueue?.flushForTest();
    if (_selectedDocument?.metadata.id == documentId) {
      setState(() {
        _selectedDocument = null;
        _selectedSyncState = null;
      });
    }
    await _refreshDocuments();
  }

  /// 휴지통에서 복구한다.
  Future<void> _restoreTrashItem(String trashItemId) async {
    await widget.container.trashService.restoreFromTrash(trashItemId);
    await widget.container.indexingQueue?.flushForTest();
    await _refreshDocuments();
  }

  /// 휴지통에서 완전삭제한다.
  Future<void> _deletePermanently(String trashItemId) async {
    await widget.container.trashService.permanentlyDelete(trashItemId);
    await widget.container.indexingQueue?.flushForTest();
  }

  /// 아카이브 섹션 중앙 패널을 구성한다.
  Widget _buildArchivePanel() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 260,
          child: FolderTreePanel(
            documents: _documents,
            syncStates: _syncStates,
            selectedId: _selectedDocument?.metadata.id,
            onSelect: _selectDocument,
            onCreateDocument: _createSampleDocument,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: DocumentEditorPanel(
            document: _selectedDocument,
            syncState: _selectedSyncState,
            onSave: _saveDocument,
            onMoveToTrash: _moveToTrash,
          ),
        ),
      ],
    );
  }

  /// 중앙 패널 위젯을 반환한다.
  Widget _buildCenterPanel() {
    switch (_section) {
      case SacSection.dashboard:
        return DashboardScreen(
          dashboardService: widget.container.dashboardService,
          privacyService: widget.container.privacyService,
          localAiService: widget.container.localAiService,
          exportService: widget.container.llmSelfInfoExportService,
          onNavigate: (target) {
            switch (target) {
              case DashboardNavTarget.personalArchive:
                setState(() => _section = SacSection.personalArchive);
              case DashboardNavTarget.extractionQueue:
                setState(() => _section = SacSection.extractionQueue);
              case DashboardNavTarget.search:
                setState(() => _section = SacSection.search);
              case DashboardNavTarget.privacy:
                setState(() => _section = SacSection.privacy);
              case DashboardNavTarget.workQueue:
                setState(() => _section = SacSection.workQueue);
            }
          },
        );
      case SacSection.privacy:
        return PrivacyScreen(privacyService: widget.container.privacyService);
      case SacSection.search:
        return SearchPanel(
          searchService: widget.container.searchService,
          onOpenDocument: _openDocumentById,
        );
      case SacSection.trash:
        return TrashPanel(
          trashService: widget.container.trashService,
          onRestore: _restoreTrashItem,
          onDeletePermanently: _deletePermanently,
        );
      case SacSection.archive:
        return _buildArchivePanel();
      case SacSection.personalArchive:
        return PersonalArchivePanel(
          personalArchiveService: widget.container.personalArchiveService,
          journalCommentService: widget.container.journalCommentService,
        );
      case SacSection.extractionQueue:
        return ExtractionQueuePanel(
          extractionQueueService: widget.container.extractionQueueService,
        );
      case SacSection.workQueue:
        return WorkQueuePanel(
          workQueueService: widget.container.workQueueService,
          queueExecutionService: widget.container.queueExecutionService,
          executionRecoveryService: widget.container.executionRecoveryService,
        );
      case SacSection.integrity:
        return IntegrityScreen(
          integrityService: widget.container.workspaceIntegrityService,
          smokeTestRecordService: widget.container.smokeTestRecordService,
          reportConsistencyService: widget.container.reportConsistencyService,
        );
    }
  }

  /// 문서 아카이브 섹션에서만 우측 컨텍스트 패널을 표시한다.
  bool get _showDocumentContext =>
      _section == SacSection.archive;

  @override
  Widget build(BuildContext context) {
    final workspace = widget.container.activeWorkspace;
    final themeController = widget.container.themeController;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 240,
                  child: LeftSidebar(
                    selected: _section,
                    onSectionChanged: (section) {
                      setState(() => _section = section);
                    },
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _buildCenterPanel()),
                if (_showDocumentContext) ...[
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 300,
                    child: RightContextPanel(
                      document: _selectedDocument,
                      syncState: _selectedSyncState,
                      onSaveMetadata: _saveMetadata,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          FooterBar(
            workspaceName: workspace?.name,
            workspacePath: workspace?.rootPath,
            syncState: _selectedSyncState,
            mcpBridgeService: widget.container.mcpBridgeStatusService,
            highContrastEnabled: themeController.highContrastEnabled,
            onHighContrastChanged: themeController.toggleHighContrast,
          ),
        ],
      ),
    );
  }
}
