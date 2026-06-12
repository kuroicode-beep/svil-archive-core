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
import '../data/services/build_environment_check_service_impl.dart';
import '../data/services/execution_recovery_service_impl.dart';
import '../data/services/release_checklist_export_service_impl.dart';
import '../data/services/final_release_bundle_export_service_impl.dart';
import '../data/services/rc_build_artifact_service_impl.dart';
import '../data/services/rc_tag_readiness_service_impl.dart';
import '../data/services/release_approval_service_impl.dart';
import '../data/services/release_finalization_export_service_impl.dart';
import '../data/services/release_readiness_service_impl.dart';
import '../data/services/smoke_approval_service_impl.dart';
import '../data/services/verification_pass_record_service_impl.dart';
import '../data/services/queue_execution_service_impl.dart';
import '../data/services/report_consistency_service_impl.dart';
import '../data/services/safe_apply_service_impl.dart';
import '../data/services/smoke_test_record_service_impl.dart';
import '../data/services/work_queue_service_impl.dart';
import '../data/services/workspace_file_inventory_service_impl.dart';
import '../data/services/document_import_service_impl.dart';
import '../data/services/import_queue_service_impl.dart';
import '../data/services/git_sync_service_impl.dart';
import '../data/services/download_watcher_service_impl.dart';
import '../data/services/download_import_coordinator.dart';
import '../data/services/relay_queue_service_impl.dart';
import '../data/db/sqlite_write_guard.dart';
import '../data/relay/relay_capability_token_service.dart';
import '../data/relay/relay_idempotency_service.dart';
import '../data/relay/relay_result_intake_service.dart';
import '../data/relay/relay_sensitivity_service.dart';
import '../data/relay/public_lumi_gc_service.dart';
import '../data/sync/relay_journal_service.dart';
import '../data/services/workspace_integrity_service_impl.dart';
import '../data/services/search_service_impl.dart';
import '../data/services/settings_service_impl.dart';
import '../data/services/sidecar_process_manager_impl.dart';
import '../data/services/windows_autostart_service_impl.dart';
import '../data/services/theme_service_impl.dart';
import '../data/services/trash_service_impl.dart';
import '../data/services/workspace_registry.dart';
import '../data/services/workspace_service_impl.dart';
import '../data/sync/sync_journal_writer.dart';
import '../data/sync/workspace_file_watcher.dart';
import 'sac_theme_controller.dart';
import '../data/sync/sync_service_impl.dart';
import '../domain/models/workspace.dart';
import '../domain/models/settings.dart';
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
import '../domain/services/build_environment_check_service.dart';
import '../domain/services/execution_recovery_service.dart';
import '../domain/services/release_checklist_export_service.dart';
import '../domain/services/final_release_bundle_export_service.dart';
import '../domain/services/rc_build_artifact_service.dart';
import '../domain/services/rc_tag_readiness_service.dart';
import '../domain/services/release_approval_service.dart';
import '../domain/services/release_finalization_export_service.dart';
import '../domain/services/release_readiness_service.dart';
import '../domain/services/smoke_approval_service.dart';
import '../domain/services/verification_pass_record_service.dart';
import '../domain/services/queue_execution_service.dart';
import '../domain/services/report_consistency_service.dart';
import '../domain/services/smoke_test_record_service.dart';
import '../domain/services/work_queue_service.dart';
import '../domain/services/workspace_file_inventory_service.dart';
import '../domain/services/document_import_service.dart';
import '../domain/services/import_queue_service.dart';
import '../domain/services/relay_queue_service.dart';
import '../domain/services/git_sync_service.dart';
import '../domain/services/download_watcher_service.dart';
import '../domain/services/workspace_integrity_service.dart';
import '../domain/services/search_service.dart';
import '../domain/services/sidecar_process_manager.dart';
import '../domain/services/sync_service.dart';
import '../domain/services/trash_service.dart';
import '../domain/services/windows_autostart_service.dart';
import 'sac_desktop_shell.dart';

class SacContainer {
  final DatabaseServiceImpl databaseService;
  final WorkspaceServiceImpl workspaceService;
  final SettingsServiceImpl settingsService;
  final ThemeServiceImpl themeService;
  final SacThemeController themeController;
  final SidecarProcessManager sidecarProcessManager;
  final WindowsAutostartService windowsAutostartService;
  final SacDesktopShell desktopShell;

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
  DocumentImportService? _documentImportService;
  ImportQueueService? _importQueueService;
  SqliteWriteGuard? _sqliteWriteGuard;
  RelayIdempotencyService? _relayIdempotencyService;
  RelayJournalService? _relayJournalService;
  RelayQueueService? _relayQueueService;
  RelaySensitivityService? _relaySensitivityService;
  RelayCapabilityTokenService? _relayCapabilityTokenService;
  RelayResultIntakeService? _relayResultIntakeService;
  PublicLumiGcService? _publicLumiGcService;
  GitSyncService? _gitSyncService;
  DownloadWatcherService? _downloadWatcherService;
  DownloadImportCoordinator? _downloadImportCoordinator;
  WorkspaceFileInventoryService? _fileInventoryService;
  ExecutionRecoveryService? _executionRecoveryService;
  SmokeTestRecordService? _smokeTestRecordService;
  ReportConsistencyService? _reportConsistencyService;
  BuildEnvironmentCheckService? _buildEnvironmentCheckService;
  ReleaseReadinessService? _releaseReadinessService;
  ReleaseChecklistExportService? _releaseChecklistExportService;
  VerificationPassRecordService? _verificationPassRecordService;
  ReleaseFinalizationExportService? _releaseFinalizationExportService;
  RcBuildArtifactService? _rcBuildArtifactService;
  SmokeApprovalService? _smokeApprovalService;
  ReleaseApprovalService? _releaseApprovalService;
  RcTagReadinessService? _rcTagReadinessService;
  FinalReleaseBundleExportService? _finalReleaseBundleExportService;
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
    required this.sidecarProcessManager,
    required this.windowsAutostartService,
    required this.desktopShell,
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
    final settingsService = SettingsServiceImpl(databaseService: databaseService);
    final sidecarProcessManager = SidecarProcessManagerImpl(settingsService: settingsService);
    final windowsAutostartService = WindowsAutostartServiceImpl();
    final desktopShell = SacDesktopShell(
      settingsService: settingsService,
      sidecarProcessManager: sidecarProcessManager,
      windowsAutostartService: windowsAutostartService,
    );
    return SacContainer._(
      databaseService: databaseService,
      workspaceService: WorkspaceServiceImpl(
        databaseService: databaseService,
        registry: WorkspaceRegistry(overrideDirectory: registryDirectory),
      ),
      settingsService: settingsService,
      themeService: themeService,
      themeController: themeController,
      sidecarProcessManager: sidecarProcessManager,
      windowsAutostartService: windowsAutostartService,
      desktopShell: desktopShell,
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

  DocumentImportService get documentImportService {
    final service = _documentImportService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  ImportQueueService get importQueueService {
    final service = _importQueueService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  GitSyncService get gitSyncService {
    final service = _gitSyncService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  DownloadWatcherService get downloadWatcherService {
    final service = _downloadWatcherService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  DownloadImportCoordinator get downloadImportCoordinator {
    final service = _downloadImportCoordinator;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  RelayQueueService get relayQueueService {
    final service = _relayQueueService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  RelayJournalService get relayJournalService {
    final service = _relayJournalService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  RelaySensitivityService get relaySensitivityService {
    final service = _relaySensitivityService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  RelayResultIntakeService get relayResultIntakeService {
    final service = _relayResultIntakeService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  RelayCapabilityTokenService get relayCapabilityTokenService {
    final service = _relayCapabilityTokenService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  PublicLumiGcService get publicLumiGcService {
    final service = _publicLumiGcService;
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

  BuildEnvironmentCheckService get buildEnvironmentCheckService {
    final service = _buildEnvironmentCheckService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  ReleaseReadinessService get releaseReadinessService {
    final service = _releaseReadinessService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  ReleaseChecklistExportService get releaseChecklistExportService {
    final service = _releaseChecklistExportService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  VerificationPassRecordService get verificationPassRecordService {
    final service = _verificationPassRecordService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  ReleaseFinalizationExportService get releaseFinalizationExportService {
    final service = _releaseFinalizationExportService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  RcBuildArtifactService get rcBuildArtifactService {
    final service = _rcBuildArtifactService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  SmokeApprovalService get smokeApprovalService {
    final service = _smokeApprovalService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  ReleaseApprovalService get releaseApprovalService {
    final service = _releaseApprovalService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  RcTagReadinessService get rcTagReadinessService {
    final service = _rcTagReadinessService;
    if (service == null) throw StateError('Workspace is not opened');
    return service;
  }

  FinalReleaseBundleExportService get finalReleaseBundleExportService {
    final service = _finalReleaseBundleExportService;
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
    final sidecarResolution = resolveMcpSidecarPath();
    _mcpBridgeStatusService = McpBridgeStatusServiceImpl(
      toolRegistry: _mcpToolRegistryService!,
      workQueue: _workQueueService!,
      sidecarResolution: sidecarResolution,
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
    _documentImportService = DocumentImportServiceImpl(
      databaseService: databaseService,
      repository: _repository!,
      fileStore: fileStore,
      inventoryService: _fileInventoryService!,
      syncService: _syncService!,
      indexingQueue: _indexingQueue!,
      workspaceId: workspace.id,
      workspaceRoot: workspace.rootPath,
    );
    _importQueueService = ImportQueueServiceImpl(databaseService: databaseService);
    _sqliteWriteGuard = SqliteWriteGuard();
    _relayIdempotencyService = RelayIdempotencyService(
      databaseService: databaseService,
      writeGuard: _sqliteWriteGuard,
    );
    _relayJournalService = RelayJournalService(
      databaseService: databaseService,
      workspaceRoot: workspace.rootPath,
      idempotencyService: _relayIdempotencyService!,
      writeGuard: _sqliteWriteGuard,
    );
    _relayCapabilityTokenService = RelayCapabilityTokenService(
      databaseService: databaseService,
      writeGuard: _sqliteWriteGuard,
    );
    _relayQueueService = RelayQueueServiceImpl(
      databaseService: databaseService,
      journalService: _relayJournalService!,
      writeGuard: _sqliteWriteGuard,
    );
    _relaySensitivityService = RelaySensitivityService();
    _relayResultIntakeService = RelayResultIntakeService(
      databaseService: databaseService,
      tokenService: _relayCapabilityTokenService!,
      journalService: _relayJournalService!,
      writeGuard: _sqliteWriteGuard,
    );
    _publicLumiGcService = PublicLumiGcService(
      databaseService: databaseService,
      journalService: _relayJournalService!,
      writeGuard: _sqliteWriteGuard,
    );
    await _publicLumiGcService!.runGc(workspaceRoot: workspace.rootPath);
    _downloadImportCoordinator = DownloadImportCoordinator(
      queueService: _importQueueService!,
      importService: _documentImportService!,
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
    _buildEnvironmentCheckService = BuildEnvironmentCheckServiceImpl(
      databaseService: databaseService,
      workspaceRoot: workspace.rootPath,
      mcpSidecarDistPath: sidecarResolution.distPath,
    );
    _verificationPassRecordService = VerificationPassRecordServiceImpl(
      databaseService: databaseService,
    );
    _releaseReadinessService = ReleaseReadinessServiceImpl(
      databaseService: databaseService,
      integrityService: _workspaceIntegrityService!,
      smokeTestRecordService: _smokeTestRecordService!,
      reportConsistencyService: _reportConsistencyService!,
      mcpBridgeService: _mcpBridgeStatusService!,
      workQueueService: _workQueueService!,
      queueExecutionService: _queueExecutionService!,
      settingsService: settingsService,
      buildEnvironmentCheckService: _buildEnvironmentCheckService!,
      verificationPassRecordService: _verificationPassRecordService!,
    );
    _releaseFinalizationExportService = ReleaseFinalizationExportServiceImpl(
      databaseService: databaseService,
      workspaceRoot: workspace.rootPath,
      releaseReadinessService: _releaseReadinessService!,
      verificationPassRecordService: _verificationPassRecordService!,
      smokeTestRecordService: _smokeTestRecordService!,
    );
    _rcBuildArtifactService = RcBuildArtifactServiceImpl(databaseService: databaseService);
    _smokeApprovalService = SmokeApprovalServiceImpl(
      smokeTestRecordService: _smokeTestRecordService!,
    );
    _releaseApprovalService = ReleaseApprovalServiceImpl(
      databaseService: databaseService,
      releaseReadinessService: _releaseReadinessService!,
      exportService: _releaseFinalizationExportService!,
      verificationService: _verificationPassRecordService!,
      smokeApprovalService: _smokeApprovalService!,
      integrityService: _workspaceIntegrityService!,
    );
    _rcTagReadinessService = RcTagReadinessServiceImpl(
      databaseService: databaseService,
      releaseReadinessService: _releaseReadinessService!,
      verificationService: _verificationPassRecordService!,
      exportService: _releaseFinalizationExportService!,
      smokeApprovalService: _smokeApprovalService!,
      releaseApprovalService: _releaseApprovalService!,
    );
    _finalReleaseBundleExportService = FinalReleaseBundleExportServiceImpl(
      databaseService: databaseService,
      workspaceRoot: workspace.rootPath,
      releaseReadinessService: _releaseReadinessService!,
      releaseApprovalService: _releaseApprovalService!,
      smokeApprovalService: _smokeApprovalService!,
      buildArtifactService: _rcBuildArtifactService!,
      tagReadinessService: _rcTagReadinessService!,
      finalizationExportService: _releaseFinalizationExportService!,
      verificationService: _verificationPassRecordService!,
    );
    _releaseChecklistExportService = ReleaseChecklistExportServiceImpl(
      databaseService: databaseService,
      workspaceRoot: workspace.rootPath,
      releaseReadinessService: _releaseReadinessService!,
      buildEnvironmentCheckService: _buildEnvironmentCheckService!,
      smokeTestRecordService: _smokeTestRecordService!,
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
      releaseReadinessService: _releaseReadinessService!,
      releaseFinalizationExportService: _releaseFinalizationExportService!,
      releaseApprovalService: _releaseApprovalService!,
      rcBuildArtifactService: _rcBuildArtifactService!,
      rcTagReadinessService: _rcTagReadinessService!,
      finalReleaseBundleExportService: _finalReleaseBundleExportService!,
    );
    _privacyService = PrivacyServiceImpl(
      databaseService: databaseService,
      permissionTokenService: _permissionTokenService!,
      toolRegistryService: _mcpToolRegistryService!,
      mcpBridgeService: _mcpBridgeStatusService!,
      queueExecutionService: _queueExecutionService!,
      integrityService: _workspaceIntegrityService!,
      reportConsistencyService: _reportConsistencyService!,
      releaseReadinessService: _releaseReadinessService!,
    );
    final currentSettings = await settingsService.getSettings();
    _localAiService = OllamaAdapter(baseUrl: currentSettings.ollamaEndpoint);
    _llmSelfInfoExportService = LlmSelfInfoExportServiceImpl(
      databaseService: databaseService,
      workspaceRoot: workspace.rootPath,
    );

    _gitSyncService = GitSyncServiceImpl(
      workspaceRoot: workspace.rootPath,
      defaultRemoteName: currentSettings.gitSync.remoteName,
      defaultBranch: currentSettings.gitSync.branch,
    );
    _downloadWatcherService = DownloadWatcherServiceImpl(
      queueService: _importQueueService!,
      settingsProvider: () async => (await settingsService.getSettings()).downloads,
      coordinator: _downloadImportCoordinator!,
      onQueueChanged: () => onWorkspaceFileChanged?.call(),
    );

    _fileWatcher = WorkspaceFileWatcher(
      onChanged: _onFileChanged,
    );
    await _fileWatcher!.start(workspace.rootPath);

    await settingsService.saveSettings(
      currentSettings.copyWith(workspaceId: workspace.id),
    );
    await themeController.load();
    await desktopShell.activateFromSettings();

    // 다운로드 감시는 설정에서 명시적으로 켰을 때만 시작한다 (기본 OFF).
    if (currentSettings.downloads.enabled) {
      await _downloadWatcherService!.start();
    }
    return workspace;
  }

  /// 설정 변경 후 다운로드 감시 상태를 재적용한다 (폴더 변경 시 재시작).
  Future<void> applyDownloadWatcherSettings(DownloadWatcherSettings settings) async {
    final watcher = _downloadWatcherService;
    if (watcher == null) return;
    if (settings.enabled) {
      if (watcher.isRunning) {
        await watcher.stop();
      }
      await watcher.start();
    } else if (watcher.isRunning) {
      await watcher.stop();
    }
  }

  /// 파일 변경 이벤트를 sync + indexing에 연결한다.
  Future<void> _onFileChanged(String relativePath) async {
    if (_syncService == null || _fileWatcher?.isWatching != true) return;
    try {
      await _syncService!.onFileChanged(relativePath);
      final doc = await _repository?.findByPath(relativePath);
      if (doc != null) {
        _indexingQueue?.queueDocument(doc.id);
      }
      onWorkspaceFileChanged?.call();
    } catch (_) {
      // tearDown 이후 debounce 콜백이 도착한 경우 무시한다.
    }
  }

  /// 테스트 tearDown에서 file watcher와 DB를 순서대로 정리한다.
  Future<void> disposeForTest() async {
    await _fileWatcher?.stop();
    await _downloadWatcherService?.stop();
    await sidecarProcessManager.dispose();
    _syncService = null;
    _repository = null;
    await databaseService.close();
  }

  /// 테스트/수동 트리거용 파일 변경 이벤트를 전달한다.
  Future<void> notifyFileChangedForTest(String relativePath) async {
    await _fileWatcher?.notifyChanged(relativePath);
  }

  /// Ollama endpoint 변경 시 LocalAiService를 갱신한다.
  void updateOllamaEndpoint(String endpoint) {
    _localAiService = OllamaAdapter(baseUrl: endpoint);
  }
}
