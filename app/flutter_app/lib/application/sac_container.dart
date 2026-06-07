// sac_container.dart — Sprint 4 서비스 조립 및 Workspace 컨텍스트 관리

import 'package:flutter/foundation.dart';

import '../data/db/database_service_impl.dart';
import '../data/db/document_repository_impl.dart';
import '../data/file/document_file_store_impl.dart';
import '../data/indexing/document_indexer.dart';
import '../data/indexing/indexing_queue.dart';
import '../data/services/archive_service_impl.dart';
import '../data/services/extraction_queue_service_impl.dart';
import '../data/services/journal_comment_service_impl.dart';
import '../data/services/personal_archive_service_impl.dart';
import '../data/services/search_service_impl.dart';
import '../data/services/settings_service_impl.dart';
import '../data/services/theme_service_impl.dart';
import '../data/services/trash_service_impl.dart';
import '../data/services/workspace_registry.dart';
import '../data/services/workspace_service_impl.dart';
import '../data/sync/sync_journal_writer.dart';
import '../data/sync/workspace_file_watcher.dart';
import 'sac_theme_controller.dart';
import '../data/sync/sync_service_impl.dart';
import '../domain/models/settings.dart';
import '../domain/models/workspace.dart';
import '../domain/services/archive_service.dart';
import '../domain/services/extraction_queue_service.dart';
import '../domain/services/journal_comment_service.dart';
import '../domain/services/personal_archive_service.dart';
import '../domain/services/search_service.dart';
import '../domain/services/sync_service.dart';
import '../domain/services/trash_service.dart';

class SacContainer {
  final DatabaseServiceImpl databaseService;
  final WorkspaceServiceImpl workspaceService;
  final SettingsServiceImpl settingsService;
  final ThemeServiceImpl themeService;
  final SacThemeController themeController;

  ArchiveService? _archiveService;
  SearchService? _searchService;
  TrashService? _trashService;
  PersonalArchiveService? _personalArchiveService;
  ExtractionQueueService? _extractionQueueService;
  JournalCommentService? _journalCommentService;
  IndexingQueue? _indexingQueue;
  SyncServiceImpl? _syncService;
  WorkspaceFileWatcher? _fileWatcher;
  DocumentRepositoryImpl? _repository;
  Workspace? _workspace;
  VoidCallback? onWorkspaceFileChanged;

  SacContainer._({
    required this.databaseService,
    required this.workspaceService,
    required this.settingsService,
    required this.themeService,
    required this.themeController,
  });

  /// 앱 시작 시 기본 컨테이너를 생성한다.
  static Future<SacContainer> create({String? registryDirectory}) async {
    final databaseService = DatabaseServiceImpl();
    final themeService = ThemeServiceImpl(databaseService: databaseService);
    final themeController = SacThemeController(themeService);
    return SacContainer._(
      databaseService: databaseService,
      workspaceService: WorkspaceServiceImpl(
        databaseService: databaseService,
        registry: WorkspaceRegistry(overrideDirectory: registryDirectory),
      ),
      settingsService: SettingsServiceImpl(databaseService: databaseService),
      themeService: themeService,
      themeController: themeController,
    );
  }

  Workspace? get activeWorkspace => _workspace;
  IndexingQueue? get indexingQueue => _indexingQueue;

  ArchiveService get archiveService {
    final service = _archiveService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  SearchService get searchService {
    final service = _searchService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  TrashService get trashService {
    final service = _trashService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  SyncService get syncService {
    final service = _syncService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  PersonalArchiveService get personalArchiveService {
    final service = _personalArchiveService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  ExtractionQueueService get extractionQueueService {
    final service = _extractionQueueService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  JournalCommentService get journalCommentService {
    final service = _journalCommentService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  /// Workspace를 열고 관련 서비스를 초기화한다.
  Future<Workspace> bindWorkspace(Workspace workspace) async {
    _workspace = workspace;
    final db = databaseService.requireDatabase();
    final journalWriter = SyncJournalWriter(
      db: db,
      workspaceRoot: workspace.rootPath,
    );
    _syncService = SyncServiceImpl(
      databaseService: databaseService,
      journalWriter: journalWriter,
    );
    final fileStore = DocumentFileStoreImpl(workspaceRoot: workspace.rootPath);
    _repository = DocumentRepositoryImpl(
      databaseService: databaseService,
      workspaceId: workspace.id,
    );

    final indexer = DocumentIndexer(
      databaseService: databaseService,
      repository: _repository!,
      fileStore: fileStore,
      workspaceId: workspace.id,
    );
    _indexingQueue = IndexingQueue(indexer: indexer);

    _trashService = TrashServiceImpl(
      databaseService: databaseService,
      repository: _repository!,
      fileStore: fileStore,
      syncService: _syncService!,
      indexingQueue: _indexingQueue!,
      workspaceRoot: workspace.rootPath,
    );

    _archiveService = ArchiveServiceImpl(
      repository: _repository!,
      fileStore: fileStore,
      syncService: _syncService!,
      indexingQueue: _indexingQueue!,
      trashService: _trashService!,
      workspaceId: workspace.id,
    );

    _searchService = SearchServiceImpl(
      databaseService: databaseService,
      repository: _repository!,
      workspaceId: workspace.id,
    );

    _personalArchiveService = PersonalArchiveServiceImpl(
      databaseService: databaseService,
    );
    _extractionQueueService = ExtractionQueueServiceImpl(
      databaseService: databaseService,
    );
    _journalCommentService = JournalCommentServiceImpl(
      databaseService: databaseService,
    );

    _fileWatcher = WorkspaceFileWatcher(
      onChanged: _onFileChanged,
    );
    await _fileWatcher!.start(workspace.rootPath);

    final current = await settingsService.getSettings();
    await settingsService.saveSettings(
      AppSettings(
        workspaceId: workspace.id,
        theme: current.theme,
        tts: current.tts,
        mcpEnabled: current.mcpEnabled,
      ),
    );
    await themeController.load();
    return workspace;
  }

  /// 파일 변경 이벤트를 sync + indexing에 연결한다.
  Future<void> _onFileChanged(String relativePath) async {
    await _syncService?.onFileChanged(relativePath);
    final doc = await _repository?.findByPath(relativePath);
    if (doc != null) {
      _indexingQueue?.queueDocument(doc.id);
    }
    onWorkspaceFileChanged?.call();
  }

  /// 테스트/수동 트리거용 파일 변경 이벤트를 전달한다.
  Future<void> notifyFileChangedForTest(String relativePath) async {
    await _fileWatcher?.notifyChanged(relativePath);
  }
}
