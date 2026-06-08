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

  test('executeApprovedImport uses snapshot candidates only', () async {
    await bindWorkspace();
    const relA = 'documents/Dev/snapshot_a_s15.md';
    const relB = 'documents/Dev/snapshot_b_s15.md';
    await writeOrphan(relA, content: '# A\n\nsnapshot-a-body');
    await writeOrphan(relB, content: '# B\n\nsnapshot-b-body');
    final root = container.activeWorkspace!.rootPath;
    final absA = p.join(root, relA);

    final preview = await container.documentImportService.scanPaths(
      [absA],
      const DocumentImportOptions(),
    );
    final snapshot = ImportApprovedSnapshot(
      options: const DocumentImportOptions(dryRunOnly: false),
      preview: preview,
    );
    final result = await container.documentImportService.executeApprovedImport(snapshot);
    expect(result.registeredCount, 1);

    final docs = await container.archiveService.listDocuments();
    expect(docs.length, 1);
    expect(docs.first.path, relA);
    expect(docs.any((d) => d.path == relB), isFalse);
  });

  test('external copy blocks existing workspace target path', () async {
    await bindWorkspace();
    const targetRel = 'documents/Import/external_conflict_s15.md';
    await writeOrphan(targetRel, content: '# existing orphan\n\nkeep');

    final externalDir = await Directory(p.join(tempDir.path, 'external_src'))
        .create(recursive: true);
    final externalFile = File(p.join(externalDir.path, 'external_conflict_s15.md'));
    await externalFile.writeAsString('# external\n\nnew content');

    final preview = await container.documentImportService.scanPaths(
      [externalFile.path],
      const DocumentImportOptions(),
    );
    final match = preview.candidates
        .where((c) => c.relativePath == targetRel)
        .toList();
    expect(match.length, 1);
    expect(match.first.status, ImportCandidateStatus.conflictTargetPath);

    final before = await File(p.join(container.activeWorkspace!.rootPath, targetRel))
        .readAsString();
    expect(before, contains('keep'));
  });

  test('dry-run detects sac_id conflict', () async {
    await bindWorkspace();
    const sharedSacId = 'sac_conflict_test_s15';
    await writeOrphan(
      'documents/Dev/existing_sac_s15.md',
      content: '---\nsac_id: $sharedSacId\n---\n\nexisting',
    );
    await writeOrphan(
      'documents/Dev/conflict_sac_s15.md',
      content: '---\nsac_id: $sharedSacId\n---\n\nconflict',
    );

    final preview = await container.documentImportService.scanWorkspaceOrphans(
      const DocumentImportOptions(),
    );
    expect(
      preview.candidates.any((c) => c.status == ImportCandidateStatus.conflictSacId),
      isTrue,
    );
  });

  test('dry-run detects duplicate content hash', () async {
    await bindWorkspace();
    const body = '# Dup\n\nsame-body-token-s15';
    await writeOrphan(
      'documents/Dev/dup_a_s15.md',
      content: '---\nsac_id: dup_a_sac_s15\n---\n$body',
    );
    await writeOrphan(
      'documents/Dev/dup_b_s15.md',
      content: '---\nsac_id: dup_b_sac_s15\n---\n$body',
    );

    final preview = await container.documentImportService.scanWorkspaceOrphans(
      const DocumentImportOptions(),
    );
    expect(
      preview.candidates.where((c) => c.status == ImportCandidateStatus.duplicateHash).length,
      greaterThanOrEqualTo(1),
    );
  });

  test('frontmatter write off keeps markdown without sac_id block', () async {
    await bindWorkspace();
    const rel = 'documents/Dev/no_fm_s15.md';
    await writeOrphan(rel, content: '# No FM\n\nplain');
    final abs = p.join(container.activeWorkspace!.rootPath, rel);
    final preview = await container.documentImportService.scanPaths(
      [abs],
      const DocumentImportOptions(writeFrontmatter: false),
    );
    final snapshot = ImportApprovedSnapshot(
      options: const DocumentImportOptions(
        dryRunOnly: false,
        writeFrontmatter: false,
      ),
      preview: preview,
    );
    await container.documentImportService.executeApprovedImport(snapshot);

    final raw = await File(abs).readAsString();
    expect(raw.startsWith('---'), isFalse);
    expect(raw, contains('plain'));
    final docs = await container.archiveService.listDocuments();
    expect(docs.length, 1);
  });

  test('bulk import increases document count for MCP/UI parity', () async {
    await bindWorkspace();
    await writeOrphan('documents/Dev/count_1_s15.md', content: '# One\n\nbody-one-s15');
    await writeOrphan('documents/Dev/count_2_s15.md', content: '# Two\n\nbody-two-s15');
    await writeOrphan('documents/Dev/count_3_s15.md', content: '# Three\n\nbody-three-s15');

    final preview = await container.documentImportService.scanWorkspaceOrphans(
      const DocumentImportOptions(),
    );
    final snapshot = ImportApprovedSnapshot(
      options: const DocumentImportOptions(dryRunOnly: false),
      preview: preview,
    );
    final result = await container.documentImportService.executeApprovedImport(snapshot);
    expect(result.registeredCount, greaterThanOrEqualTo(3));

    final docs = await container.archiveService.listDocuments();
    expect(docs.length, greaterThanOrEqualTo(3));
  });
}
