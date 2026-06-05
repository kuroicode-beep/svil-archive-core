// archive_integration_test.dart — Workspace/Markdown/SQLite 통합 테스트

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/platform/path_adapter.dart';
import 'package:sac_app/domain/services/archive_service.dart';

void main() {
  late Directory tempDir;
  late SacContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sac_sprint2_test_');
    container = await SacContainer.create(registryDirectory: tempDir.path);
  });

  tearDown(() async {
    await container.databaseService.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('create workspace and document persists to sqlite and markdown', () async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Test WS',
      rootPath: p.join(tempDir.path, 'SAC DOCS'),
    );
    await container.bindWorkspace(workspace);

    final archive = container.archiveService;
    final created = await archive.createDocument(
      const CreateDocumentInput(
        title: 'IntegrationDoc',
        type: 'Dev',
        relativeDir: 'documents/Dev',
        initialContent: 'integration body',
        author: 'user',
      ),
    );

    final listed = await archive.listDocuments();
    expect(listed.any((d) => d.id == created.metadata.id), isTrue);

    final loaded = await archive.getDocumentWithContent(created.metadata.id);
    expect(loaded?.content?.rawMarkdown, 'integration body');

    final sync = await container.syncService.getSyncState(created.metadata.id);
    expect(sync.revision, 1);

    final updated = await archive.updateDocument(
      UpdateDocumentInput(
        id: created.metadata.id,
        content: 'updated body',
        author: 'user',
        baseRevision: 1,
      ),
    );
    expect(updated.metadata.contentHash, isNot(created.metadata.contentHash));

    final syncAfter = await container.syncService.getSyncState(created.metadata.id);
    expect(syncAfter.revision, 2);
    expect(syncAfter.status.name, 'userModified');

    final dbFile = File(p.join(workspace.rootPath, '.sac', 'sac.sqlite'));
    expect(await dbFile.exists(), isTrue);

    final listedRevision = listed.firstWhere((d) => d.id == created.metadata.id).revision;
    expect(listedRevision, 1);

    await expectLater(
      archive.createDocument(
        const CreateDocumentInput(
          title: 'Escape',
          type: '../../outside',
          relativeDir: 'documents/Dev',
          initialContent: 'bad',
        ),
      ),
      throwsA(isA<WorkspacePathException>()),
    );
  });
}
