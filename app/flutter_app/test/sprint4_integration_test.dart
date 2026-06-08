// sprint4_integration_test.dart — Document Archive UI / Theme / Watcher 통합 테스트

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/platform/path_adapter.dart';
import 'package:sac_app/domain/services/archive_service.dart';
import 'package:sac_app/ui/widgets/folder_tree_panel.dart';

void main() {
  late Directory tempDir;
  late SacContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sac_sprint4_test_');
    container = await SacContainer.create(registryDirectory: tempDir.path);
  });

  tearDown(() async {
    await container.disposeForTest();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('folder tree groups documents by category', () async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Tree WS',
      rootPath: p.join(tempDir.path, 'SAC TREE'),
    );
    await container.bindWorkspace(workspace);

    await container.archiveService.createDocument(
      const CreateDocumentInput(
        title: 'DevDoc',
        relativeDir: 'documents/Dev',
        initialContent: 'dev',
      ),
    );
    await container.archiveService.createDocument(
      const CreateDocumentInput(
        title: 'LogDoc',
        relativeDir: 'documents/Log',
        initialContent: 'log',
      ),
    );

    final docs = await container.archiveService.listDocuments();
    final tree = buildFolderTree(docs);
    expect(tree.length, 2);
    expect(tree.any((node) => node.label == 'Dev' && node.children.length == 1), isTrue);
    expect(tree.any((node) => node.label == 'Log' && node.children.length == 1), isTrue);
  });

  test('metadata update persists to sqlite', () async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Meta WS',
      rootPath: p.join(tempDir.path, 'SAC META'),
    );
    await container.bindWorkspace(workspace);

    final created = await container.archiveService.createDocument(
      const CreateDocumentInput(
        title: 'MetaDoc',
        relativeDir: 'documents/Dev',
        initialContent: 'meta test',
      ),
    );
    final sync = await container.syncService.getSyncState(created.metadata.id);

    await container.archiveService.updateDocument(
      UpdateDocumentInput(
        id: created.metadata.id,
        project: 'SAC Phase 1',
        tags: ['alpha', 'beta'],
        summary: 'summary text',
        baseRevision: sync.revision,
      ),
    );

    final loaded = await container.archiveService.getDocument(created.metadata.id);
    expect(loaded?.project, 'SAC Phase 1');
    expect(loaded?.tags, ['alpha', 'beta']);
    expect(loaded?.summary, 'summary text');
  });

  test('file change marks sync_state dirty', () async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Watcher WS',
      rootPath: p.join(tempDir.path, 'SAC WATCH'),
    );
    await container.bindWorkspace(workspace);

    final created = await container.archiveService.createDocument(
      const CreateDocumentInput(
        title: 'WatchDoc',
        relativeDir: 'documents/Dev',
        initialContent: 'watch test',
      ),
    );

    await container.notifyFileChangedForTest(created.metadata.path);
    final sync = await container.syncService.getSyncState(created.metadata.id);
    expect(sync.status.name, 'dirty');
  });

  test('category change without path move is rejected', () async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Reject WS',
      rootPath: p.join(tempDir.path, 'SAC REJECT'),
    );
    await container.bindWorkspace(workspace);

    final created = await container.archiveService.createDocument(
      const CreateDocumentInput(
        title: 'RejectDoc',
        relativeDir: 'documents/Dev',
        initialContent: 'reject test',
      ),
    );
    final sync = await container.syncService.getSyncState(created.metadata.id);

    expect(
      container.archiveService.updateDocument(
        UpdateDocumentInput(
          id: created.metadata.id,
          type: 'Log',
          project: 'x',
          baseRevision: sync.revision,
        ),
      ),
      throwsA(isA<WorkspacePathException>()),
    );
  });

  test('folder tree groups by path not stale db category', () async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Stale WS',
      rootPath: p.join(tempDir.path, 'SAC STALE'),
    );
    await container.bindWorkspace(workspace);

    final created = await container.archiveService.createDocument(
      const CreateDocumentInput(
        title: 'StaleDoc',
        relativeDir: 'documents/Dev',
        initialContent: 'stale type test',
      ),
    );

    final db = container.databaseService.requireDatabase();
    await db.update(
      'documents',
      {'category': 'Log'},
      where: 'id = ?',
      whereArgs: [created.metadata.id],
    );

    final docs = await container.archiveService.listDocuments();
    final tree = buildFolderTree(docs);
    final devNode = tree.firstWhere((node) => node.label == 'Dev');
    expect(devNode.children.any((child) => child.id == created.metadata.id), isTrue);
    expect(tree.any((node) => node.label == 'Log'), isFalse);
  });

  test('high contrast toggle persists in app_settings', () async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Theme WS',
      rootPath: p.join(tempDir.path, 'SAC THEME'),
    );
    await container.bindWorkspace(workspace);

    await container.themeService.toggleHighContrast(true);
    final settings = await container.themeService.getThemeSettings();
    expect(settings.highContrastEnabled, isTrue);

    await container.themeController.toggleHighContrast(false);
    final reloaded = await container.themeService.getThemeSettings();
    expect(reloaded.highContrastEnabled, isFalse);
  });
}
