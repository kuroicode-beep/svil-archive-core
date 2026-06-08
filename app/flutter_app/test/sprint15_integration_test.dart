// sprint15_integration_test.dart — File Import Formal Registration 통합 테스트

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/import/markdown_import_parser.dart';
import 'package:sac_app/data/platform/path_adapter.dart';
import 'package:sac_app/domain/models/document_import.dart';
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
    tempDir = await Directory.systemTemp.createTemp('sac_sprint15_test_');
    container = await SacContainer.create(registryDirectory: tempDir.path);
  });

  tearDown(() async {
    await container.disposeForTest();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> bindWorkspace() async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Sprint15 WS',
      rootPath: p.join(tempDir.path, 'SAC S15'),
    );
    await container.bindWorkspace(workspace);
  }

  Future<void> writeOrphan(
    String relativePath, {
    String content = '# orphan title\n\nbody',
  }) async {
    final root = container.activeWorkspace!.rootPath;
    final file = File(p.join(root, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  test('categoryPathFromRelativePath supports custom Korean folders', () {
    expect(
      categoryPathFromRelativePath('documents/01_핵심규칙/sample.md'),
      '01_핵심규칙',
    );
    expect(
      categoryPathFromRelativePath('documents/03_프로젝트/SAC/report.md'),
      '03_프로젝트/SAC',
    );
  });

  test('parseMarkdownForImport works without sac_id', () {
    final parsed = parseMarkdownForImport('# Title\n\nhello');
    expect(parsed.sacId, isNull);
    expect(parsed.body, contains('hello'));
    expect(parsed.contentHash, isNotEmpty);
  });

  test('dry-run detects workspace orphan markdown', () async {
    await bindWorkspace();
    await writeOrphan('documents/01_핵심규칙/orphan_s15.md');
    final preview = await container.documentImportService.scanWorkspaceOrphans(
      const DocumentImportOptions(),
    );
    expect(preview.readyCount, greaterThanOrEqualTo(1));
    expect(
      preview.candidates.any((c) => c.relativePath.contains('orphan_s15.md')),
      isTrue,
    );
  });

  test('dry-run skips already registered documents', () async {
    await bindWorkspace();
    const rel = 'documents/01_핵심규칙/registered_s15.md';
    await writeOrphan(rel);
    final abs = p.join(container.activeWorkspace!.rootPath, rel);
    await container.documentImportService.executeImport(
      DocumentImportOptions(
        absolutePaths: [abs],
        dryRunOnly: false,
        writeFrontmatter: false,
      ),
    );
    final preview = await container.documentImportService.scanWorkspaceOrphans(
      const DocumentImportOptions(skipRegistered: true),
    );
    final match = preview.candidates.where((c) => c.relativePath == rel).toList();
    expect(match.length, 1);
    expect(match.first.status, ImportCandidateStatus.skipRegistered);
  });

  test('executeImport registers documents and indexes FTS', () async {
    await bindWorkspace();
    const rel = 'documents/03_프로젝트/SAC/import_fts_s15.md';
    await writeOrphan(rel, content: '# FTS Import\n\nunique sac search token xyzs15');
    final abs = p.join(container.activeWorkspace!.rootPath, rel);
    final result = await container.documentImportService.executeImport(
      DocumentImportOptions(
        absolutePaths: [abs],
        dryRunOnly: false,
        writeFrontmatter: true,
      ),
    );
    expect(result.registeredCount, 1);
    expect(result.backupPath, isNotNull);
    expect(result.reportPath, isNotNull);

    final docs = await container.archiveService.listDocuments();
    expect(docs.length, 1);
    expect(docs.first.path, rel);
    expect(docs.first.type, '03_프로젝트/SAC');

    final search = await container.searchService.search(
      const SearchQuery(text: 'xyzs15', limit: 5),
    );
    expect(search, isNotEmpty);
  });

  test('executeImport does not delete original markdown', () async {
    await bindWorkspace();
    const rel = 'documents/Dev/no_delete_s15.md';
    await writeOrphan(rel, content: '# keep me\n\noriginal');
    final abs = p.join(container.activeWorkspace!.rootPath, rel);
    await container.documentImportService.executeImport(
      DocumentImportOptions(absolutePaths: [abs], dryRunOnly: false),
    );
    expect(await File(abs).exists(), isTrue);
    final raw = await File(abs).readAsString();
    expect(raw, contains('keep me'));
  });

  test('dry-run without execute creates no DB rows', () async {
    await bindWorkspace();
    await writeOrphan('documents/Dev/dry_only_s15.md');
    await container.documentImportService.dryRun(const DocumentImportOptions());
    final docs = await container.archiveService.listDocuments();
    expect(docs, isEmpty);
  });

  test('custom folder import reduces integrity orphan count', () async {
    await bindWorkspace();
    await writeOrphan('documents/01_핵심규칙/integrity_s15.md');
    final before = await container.workspaceIntegrityService.runScan();
    expect(before.orphanCount, greaterThanOrEqualTo(1));

    final preview = await container.documentImportService.scanWorkspaceOrphans(
      const DocumentImportOptions(),
    );
    await container.documentImportService.executeImport(
      const DocumentImportOptions(dryRunOnly: false),
    );
    expect(preview.readyCount, greaterThanOrEqualTo(1));

    final after = await container.workspaceIntegrityService.runScan();
    expect(after.orphanCount, lessThan(before.orphanCount));
  });

  test('import report and backup directories exist under .sac', () async {
    await bindWorkspace();
    const rel = 'documents/IB/report_path_s15.md';
    await writeOrphan(rel);
    final abs = p.join(container.activeWorkspace!.rootPath, rel);
    final result = await container.documentImportService.executeImport(
      DocumentImportOptions(absolutePaths: [abs], dryRunOnly: false),
    );
    expect(await File(result.backupPath!).exists(), isTrue);
    expect(await File(result.reportPath!).exists(), isTrue);
    expect(
      result.reportPath!.contains(p.join('.sac', 'imports')),
      isTrue,
    );
  });

  test('subfolder scan off limits candidates', () async {
    await bindWorkspace();
    await writeOrphan('documents/01_핵심규칙/nested/nested_s15.md');
    final root = p.join(container.activeWorkspace!.rootPath, 'documents', '01_핵심규칙');
    final preview = await container.documentImportService.scanPaths(
      [root],
      const DocumentImportOptions(includeSubfolders: false),
    );
    expect(
      preview.candidates.any((c) => c.relativePath.contains('nested_s15.md')),
      isFalse,
    );
  });
}
