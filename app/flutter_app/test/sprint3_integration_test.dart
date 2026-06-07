// sprint3_integration_test.dart — Search / Indexing / Trash 통합 테스트

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/platform/path_adapter.dart';
import 'package:sac_app/domain/services/archive_service.dart';
import 'package:sac_app/domain/services/search_service.dart';

void main() {
  late Directory tempDir;
  late SacContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sac_sprint3_test_');
    container = await SacContainer.create(registryDirectory: tempDir.path);
  });

  tearDown(() async {
    await container.databaseService.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('search indexing trash restore flow', () async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Test WS',
      rootPath: p.join(tempDir.path, 'SAC DOCS'),
    );
    await container.bindWorkspace(workspace);

    final archive = container.archiveService;
    final search = container.searchService;
    final trash = container.trashService;

    final created = await archive.createDocument(
      const CreateDocumentInput(
        title: 'SearchTarget',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: '# Alpha\n\nunique_keyword_zeta content here.',
        author: 'user',
      ),
    );
    await container.indexingQueue!.flushForTest();

    final hits = await search.search(const SearchQuery(text: 'unique_keyword_zeta'));
    expect(hits.any((r) => r.document.id == created.metadata.id), isTrue);

    final trashItem = await trash.moveToTrash(created.metadata.id);
    await container.indexingQueue!.flushForTest();

    expect(
      await _syncStatus(container, created.metadata.id),
      'trashed',
    );

    final afterTrash = await search.search(const SearchQuery(text: 'unique_keyword_zeta'));
    expect(afterTrash.any((r) => r.document.id == created.metadata.id), isFalse);

    final restoredId = await trash.restoreFromTrash(trashItem.id);
    await container.indexingQueue!.flushForTest();

    expect(restoredId, created.metadata.id);
    expect(
      await _syncStatus(container, created.metadata.id),
      'dirty',
    );
    final afterRestore = await search.search(const SearchQuery(text: 'unique_keyword_zeta'));
    expect(afterRestore.any((r) => r.document.id == created.metadata.id), isTrue);
  });

  test('relativeDir and type mismatch is rejected', () {
    expect(
      () => resolveCreateDocumentRelativePath(
        relativeDir: 'documents/Log',
        type: 'Dev',
        title: 'Mismatch',
      ),
      throwsA(isA<WorkspacePathException>()),
    );
  });

  test('trash move and restore preserve sync_state row', () async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Sync WS',
      rootPath: p.join(tempDir.path, 'SAC SYNC'),
    );
    await container.bindWorkspace(workspace);

    final created = await container.archiveService.createDocument(
      const CreateDocumentInput(
        title: 'SyncStateDoc',
        relativeDir: 'documents/Dev',
        initialContent: 'sync state test',
      ),
    );

    final db = container.databaseService.requireDatabase();
    final beforeTrash = await db.query(
      'sync_state',
      where: 'document_id = ?',
      whereArgs: [created.metadata.id],
    );
    expect(beforeTrash, isNotEmpty);

    await container.trashService.moveToTrash(created.metadata.id);
    final afterTrash = await db.query(
      'sync_state',
      where: 'document_id = ?',
      whereArgs: [created.metadata.id],
    );
    expect(afterTrash, hasLength(1));
    expect(afterTrash.first['status'], 'trashed');

    final items = await container.trashService.listTrashItems();
    await container.trashService.restoreFromTrash(items.first.id);
    final afterRestore = await db.query(
      'sync_state',
      where: 'document_id = ?',
      whereArgs: [created.metadata.id],
    );
    expect(afterRestore, hasLength(1));
    expect(afterRestore.first['status'], 'dirty');
  });

  test('trash path stays inside workspace', () async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Trash WS',
      rootPath: p.join(tempDir.path, 'SAC TRASH'),
    );
    await container.bindWorkspace(workspace);

    final created = await container.archiveService.createDocument(
      const CreateDocumentInput(
        title: 'TrashMe',
        relativeDir: 'documents/Dev',
        initialContent: 'trash test',
      ),
    );

    final item = await container.trashService.moveToTrash(created.metadata.id);
    final trashAbs = resolveWorkspacePath(
      workspace.rootPath,
      '.sac/trash/${created.metadata.id}_TrashMe.md',
    );
    expect(await File(trashAbs).exists(), isTrue);
    expect(item.originalPath, 'documents/Dev/TrashMe.md');
  });
}

/// sync_state.status를 조회한다.
Future<String?> _syncStatus(SacContainer container, String documentId) async {
  final rows = await container.databaseService.requireDatabase().query(
    'sync_state',
    columns: ['status'],
    where: 'document_id = ?',
    whereArgs: [documentId],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return rows.first['status'] as String?;
}
