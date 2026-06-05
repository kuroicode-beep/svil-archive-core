// sac_container.dart — Sprint 2 서비스 조립 및 Workspace 컨텍스트 관리

import '../data/db/database_service_impl.dart';
import '../data/db/document_repository_impl.dart';
import '../data/file/document_file_store_impl.dart';
import '../data/services/archive_service_impl.dart';
import '../data/services/settings_service_impl.dart';
import '../data/services/workspace_registry.dart';
import '../data/services/workspace_service_impl.dart';
import '../data/sync/file_watcher_skeleton.dart';
import '../data/sync/sync_journal_writer.dart';
import '../data/sync/sync_service_impl.dart';
import '../domain/models/settings.dart';
import '../domain/models/workspace.dart';
import '../domain/services/archive_service.dart';
import '../domain/services/sync_service.dart';

class SacContainer {
  final DatabaseServiceImpl databaseService;
  final WorkspaceServiceImpl workspaceService;
  final SettingsServiceImpl settingsService;

  ArchiveService? _archiveService;
  SyncServiceImpl? _syncService;
  FileWatcherSkeleton? _fileWatcher;
  Workspace? _workspace;

  SacContainer._({
    required this.databaseService,
    required this.workspaceService,
    required this.settingsService,
  });

  /// 앱 시작 시 기본 컨테이너를 생성한다.
  static Future<SacContainer> create({String? registryDirectory}) async {
    final databaseService = DatabaseServiceImpl();
    return SacContainer._(
      databaseService: databaseService,
      workspaceService: WorkspaceServiceImpl(
        databaseService: databaseService,
        registry: WorkspaceRegistry(overrideDirectory: registryDirectory),
      ),
      settingsService: SettingsServiceImpl(databaseService: databaseService),
    );
  }

  Workspace? get activeWorkspace => _workspace;

  ArchiveService get archiveService {
    final service = _archiveService;
    if (service == null) {
      throw StateError('Workspace is not opened');
    }
    return service;
  }

  SyncService get syncService {
    final service = _syncService;
    if (service == null) {
      throw StateError('Workspace is not opened');
    }
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
    final repository = DocumentRepositoryImpl(
      databaseService: databaseService,
      workspaceId: workspace.id,
    );
    _archiveService = ArchiveServiceImpl(
      repository: repository,
      fileStore: fileStore,
      syncService: _syncService!,
      workspaceId: workspace.id,
    );
    _fileWatcher = FileWatcherSkeleton(
      onChanged: _syncService!.onFileChanged,
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
    return workspace;
  }
}
