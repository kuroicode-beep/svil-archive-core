// sac_container.dart — Sprint 4 서비스 조립 및 Workspace 컨텍스트 관리

import 'package:flutter/foundation.dart';

import '../data/db/database_service_impl.dart';
import '../data/db/document_repository_impl.dart';
import '../data/file/document_file_store_impl.dart';
import '../data/indexing/document_indexer.dart';
import '../data/indexing/indexing_queue.dart';
import '../data/services/archive_service_impl.dart';
import '../data/services/conflict_guard_service_impl.dart';
import '../data/services/dashboard_service_impl.dart';
import '../data/services/extraction_queue_service_impl.dart';
import '../data/services/journal_comment_service_impl.dart';
import '../data/services/llm_self_info_export_service_impl.dart';
import '../data/services/mcp_bridge_status_service_impl.dart';
import '../data/services/mcp_tool_registry_service_impl.dart';
import '../data/services/ollama_adapter.dart';
import '../data/services/permission_token_service_impl.dart';
import '../data/services/personal_archive_service_impl.dart';
import '../data/services/privacy_service_impl.dart';
import '../data/services/execution_recovery_service_impl.dart';
import '../data/services/queue_execution_service_impl.dart';
import '../data/services/report_consistency_service_impl.dart';
import '../data/services/safe_apply_service_impl.dart';
import '../data/services/smoke_test_record_service_impl.dart';
import '../data/services/work_queue_service_impl.dart';
import '../data/services/workspace_file_inventory_service_impl.dart';
import '../data/services/workspace_integrity_service_impl.dart';
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
import '../domain/services/conflict_guard_service.dart';
import '../domain/services/dashboard_service.dart';
import '../domain/services/extraction_queue_service.dart';
import '../domain/services/journal_comment_service.dart';
import '../domain/services/llm_self_info_export_service.dart';
import '../domain/services/local_ai_service.dart';
import '../domain/services/mcp_bridge_status_service.dart';
import '../domain/services/mcp_tool_registry_service.dart';
import '../domain/services/permission_token_service.dart';
import '../domain/services/personal_archive_service.dart';
import '../domain/services/privacy_service.dart';
import '../domain/services/execution_recovery_service.dart';
import '../domain/services/queue_execution_service.dart';
import '../domain/services/report_consistency_service.dart';
import '../domain/services/smoke_test_record_service.dart';
import '../domain/services/work_queue_service.dart';
import '../domain/services/workspace_file_inventory_service.dart';
import '../domain/services/workspace_integrity_service.dart';
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
  DashboardService? _dashboardService;
  PrivacyService? _privacyService;
  WorkQueueService? _workQueueService;
  ConflictGuardService? _conflictGuardService;
  McpBridgeStatusService? _mcpBridgeStatusService;
  McpToolRegistryService? _mcpToolRegistryService;
  PermissionTokenService? _permissionTokenService;
  QueueExecutionService? _queueExecutionService;
  WorkspaceIntegrityService? _workspaceIntegrityService;
  WorkspaceFileInventoryService? _fileInventoryService;
  ExecutionRecoveryService? _executionRecoveryService;
  SmokeTestRecordService? _smokeTestRecordService;
  ReportConsistencyService? _reportConsistencyService;
  LocalAiService? _localAiService;
  LlmSelfInfoExportService? _llmSelfInfoExportService;
  IndexingQueue? _indexingQueue;
  SyncServiceImpl? _syncService;
  WorkspaceFileWatcher? _fileWatcher;
  DocumentRepositoryImpl? _repository;
  Workspace? _workspace;
  final String? _reportDocsRoot;
  VoidCallback? onWorkspaceFileChanged;

  SacContainer._({
    required this.databaseService,
    required this.workspaceService,
    required this.settingsService,
    required this.themeService,
    required this.themeController,
    String? reportDocsRoot,
  }) : _reportDocsRoot = reportDocsRoot;

  /// 앱 시작 시 기본 컨테이너를 생성한다.
  static Future<SacContainer> create({
    String? registryDirectory,
    String? reportDocsRoot,
  }) async {
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
      reportDocsRoot: reportDocsRoot ?? resolveReportDocsRoot(),
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

  DashboardService get dashboardService {
    final service = _dashboardService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  PrivacyService get privacyService {
    final service = _privacyService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  LocalAiService get localAiService {
    final service = _localAiService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  LlmSelfInfoExportService get llmSelfInfoExportService {
    final service = _llmSelfInfoExportService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  WorkQueueService get workQueueService {
    final service = _workQueueService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  ConflictGuardService get conflictGuardService {
    final service = _conflictGuardService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  McpBridgeStatusService get mcpBridgeStatusService {
    final service = _mcpBridgeStatusService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  McpToolRegistryService get mcpToolRegistryService {
    final service = _mcpToolRegistryService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  PermissionTokenService get permissionTokenService {
    final service = _permissionTokenService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  QueueExecutionService get queueExecutionService {
    final service = _queueExecutionService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  WorkspaceIntegrityService get workspaceIntegrityService {
    final service = _workspaceIntegrityService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  WorkspaceFileInventoryService get fileInventoryService {
    final service = _fileInventoryService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  ExecutionRecoveryService get executionRecoveryService {
    final service = _executionRecoveryService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  SmokeTestRecordService get smokeTestRecordService {
    final service = _smokeTestRecordService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  ReportConsistencyService get reportConsistencyService {
    final service = _reportConsistencyService;
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
    _conflictGuardService = ConflictGuardServiceImpl(
      databaseService: databaseService,
      workspaceRoot: workspace.rootPath,
    );
    _mcpToolRegistryService = McpToolRegistryServiceImpl(
      databaseService: databaseService,
    );
    _permissionTokenService = PermissionTokenServiceImpl(
      databaseService: databaseService,
    );
    _workQueueService = WorkQueueServiceImpl(
      databaseService: databaseService,
      conflictGuard: _conflictGuardService!,
      permissionTokenService: _permissionTokenService!,
    );
    _mcpBridgeStatusService = McpBridgeStatusServiceImpl(
      toolRegistry: _mcpToolRegistryService!,
      workQueue: _workQueueService!,
    );
    _fileInventoryService = WorkspaceFileInventoryServiceImpl(fileStore: fileStore);
    _reportConsistencyService = ReportConsistencyServiceImpl(
      databaseService: databaseService,
      reportDocsRoot: _reportDocsRoot,
    );
    _smokeTestRecordService = SmokeTestRecordServiceImpl(
      databaseService: databaseService,
    );
    _workspaceIntegrityService = WorkspaceIntegrityServiceImpl(
      databaseService: databaseService,
      inventoryService: _fileInventoryService!,
      reportConsistencyService: _reportConsistencyService!,
      workspaceId: workspace.id,
    );
    final safeApplyService = SafeApplyServiceImpl(
      archiveService: _archiveService!,
      repository: _repository!,
      fileStore: fileStore,
      syncService: _syncService!,
    );
    _queueExecutionService = QueueExecutionServiceImpl(
      databaseService: databaseService,
      workQueueService: _workQueueService!,
      safeApplyService: safeApplyService,
      conflictGuard: _conflictGuardService!,
      permissionTokenService: _permissionTokenService!,
      toolRegistry: _mcpToolRegistryService!,
      syncService: _syncService!,
    );
    await _mcpToolRegistryService!.ensureDefaultTools();
    _executionRecoveryService = ExecutionRecoveryServiceImpl(
      databaseService: databaseService,
      workQueueService: _workQueueService!,
    );
    _dashboardService = DashboardServiceImpl(
      databaseService: databaseService,
      workQueueService: _workQueueService!,
      mcpBridgeService: _mcpBridgeStatusService!,
      toolRegistryService: _mcpToolRegistryService!,
      queueExecutionService: _queueExecutionService!,
      integrityService: _workspaceIntegrityService!,
      reportConsistencyService: _reportConsistencyService!,
      smokeTestRecordService: _smokeTestRecordService!,
    );
    _privacyService = PrivacyServiceImpl(
      databaseService: databaseService,
      permissionTokenService: _permissionTokenService!,
      toolRegistryService: _mcpToolRegistryService!,
      mcpBridgeService: _mcpBridgeStatusService!,
      queueExecutionService: _queueExecutionService!,
      integrityService: _workspaceIntegrityService!,
      reportConsistencyService: _reportConsistencyService!,
    );
    _localAiService = OllamaAdapter();
    _llmSelfInfoExportService = LlmSelfInfoExportServiceImpl(
      databaseService: databaseService,
      workspaceRoot: workspace.rootPath,
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
