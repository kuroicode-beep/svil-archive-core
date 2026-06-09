// sprint16h3_integration_test.dart — Sprint 16H-3 Archive/Import blocker UI hotfix

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/platform/path_adapter.dart';
import 'package:sac_app/domain/models/document.dart';
import 'package:sac_app/domain/models/document_import.dart';
import 'package:sac_app/domain/services/document_import_service.dart';
import 'package:sac_app/ui/screens/file_import_screen.dart';
import 'package:sac_app/ui/widgets/archive_list_panel.dart';
import 'package:sac_app/ui/widgets/folder_tree_panel.dart';

void main() {
  group('sprint16h3 integration', () {
    late Directory tempDir;
    late SacContainer container;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sac_sprint16h3_test_');
      container = await SacContainer.create(registryDirectory: tempDir.path);
    });

    tearDown(() async {
      await container.disposeForTest();
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    Future<void> bindWorkspace() async {
      final workspace = await container.workspaceService.createWorkspace(
        name: 'Sprint16H3 WS',
        rootPath: p.join(tempDir.path, 'SAC S16H3'),
      );
      await container.bindWorkspace(workspace);
    }

    test('folderCategoryFromRelativePath allows Import category', () {
      expect(
        folderCategoryFromRelativePath('documents/Import/sample.md'),
        'Import',
      );
      expect(
        folderCategoryFromRelativePath('documents/01_핵심규칙/sample.md'),
        '01_핵심규칙',
      );
    });

    test('buildFolderTree renders Import category documents', () {
      final docs = [
        DocumentMetadata(
          id: 'id-import',
          path: 'documents/Import/notion_backup.md',
          title: 'Notion Backup',
          status: DocumentStatus.active,
          createdAt: DateTime.utc(2026, 6, 9),
          updatedAt: DateTime.utc(2026, 6, 9),
          contentHash: 'hash-import',
          revision: 1,
        ),
      ];
      final tree = buildFolderTree(docs);
      expect(tree.length, 1);
      expect(tree.first.label, 'Import');
      expect(tree.first.children.length, 1);
    });

    test('korean path folder dry-run scans nested markdown', () async {
      await bindWorkspace();
      final koreanDir = await Directory(p.join(tempDir.path, '노션 백업')).create(recursive: true);
      final nested = Directory(p.join(koreanDir.path, 'sub'));
      await nested.create(recursive: true);
      await File(p.join(koreanDir.path, 'root.md')).writeAsString('# root\n\nbody');
      await File(p.join(nested.path, 'nested.md')).writeAsString('# nested\n\nbody');

      final preview = await container.documentImportService.dryRun(
        DocumentImportOptions(
          absolutePaths: [koreanDir.path],
          includeSubfolders: true,
        ),
      );
      expect(preview.candidates.length, 2);
      expect(preview.readyCount, 2);
    });

    test('dry-run with zero markdown files returns empty candidates', () async {
      await bindWorkspace();
      final emptyDir = await Directory(p.join(tempDir.path, 'empty_folder')).create();
      await File(p.join(emptyDir.path, 'readme.txt')).writeAsString('not md');

      final preview = await container.documentImportService.dryRun(
        DocumentImportOptions(absolutePaths: [emptyDir.path], includeSubfolders: true),
      );
      expect(preview.candidates, isEmpty);
      expect(preview.readyCount, 0);
    });

    test('dry-run with only registered files yields skip-only result', () async {
      await bindWorkspace();
      const rel = 'documents/Dev/already_s16h3.md';
      final root = container.activeWorkspace!.rootPath;
      final file = File(p.join(root, rel));
      await file.parent.create(recursive: true);
      await file.writeAsString('# already\n\nregistered');

      await container.documentImportService.executeImport(
        DocumentImportOptions(absolutePaths: [file.path], dryRunOnly: false),
      );

      final preview = await container.documentImportService.dryRun(
        DocumentImportOptions(absolutePaths: [file.path], skipRegistered: true),
      );
      expect(preview.readyCount, 0);
      expect(preview.skipCount, greaterThanOrEqualTo(1));
    });

    testWidgets('dry-run shows zero markdown guidance', (tester) async {
      final mock = _EmptyScanImportService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FileImportScreen(importService: mock)),
        ),
      );
      await tester.tap(find.text('Workspace orphan 스캔'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Markdown 파일을 찾지 못했습니다'), findsOneWidget);
      expect(find.textContaining('후보 0'), findsOneWidget);
    });

    testWidgets('dry-run shows skip-only guidance', (tester) async {
      final mock = _SkipOnlyImportService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FileImportScreen(importService: mock)),
        ),
      );
      await tester.tap(find.text('Workspace orphan 스캔'));
      await tester.pumpAndSettle();

      expect(find.textContaining('등록 가능한 새 파일이 없습니다'), findsOneWidget);
      final executeButton = find.widgetWithText(ElevatedButton, '정식 등록 실행');
      expect(tester.widget<ElevatedButton>(executeButton).onPressed, isNull);
    });

    testWidgets('dry-run success enables execute and shows summary', (tester) async {
      final mock = _ReadyImportService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FileImportScreen(importService: mock)),
        ),
      );
      await tester.tap(find.text('Workspace orphan 스캔'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Dry-run 결과: 후보 1'), findsOneWidget);
      expect(find.textContaining('등록 가능 1'), findsOneWidget);
      final executeButton = find.widgetWithText(ElevatedButton, '정식 등록 실행');
      expect(tester.widget<ElevatedButton>(executeButton).onPressed, isNotNull);
    });

    testWidgets('dry-run failure shows error card', (tester) async {
      final mock = _FailingImportService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FileImportScreen(importService: mock)),
        ),
      );
      await tester.tap(find.text('Workspace orphan 스캔'));
      await tester.pumpAndSettle();

      expect(find.text('Dry-run 오류'), findsOneWidget);
      expect(find.textContaining('mock scan failure'), findsOneWidget);
    });

    test('import registers document visible in archive list', () async {
      await bindWorkspace();
      final koreanDir = await Directory(p.join(tempDir.path, '노션 백업')).create(recursive: true);
      final source = File(p.join(koreanDir.path, 'archive_visible.md'));
      await source.writeAsString('# visible\n\nbody');

      final preview = await container.documentImportService.dryRun(
        DocumentImportOptions(absolutePaths: [source.path]),
      );
      final snapshot = ImportApprovedSnapshot(
        options: DocumentImportOptions(absolutePaths: [source.path], dryRunOnly: false),
        preview: preview,
      );
      await container.documentImportService.executeApprovedImport(snapshot);

      final docs = await container.archiveService.listDocuments();
      expect(docs.any((d) => d.path.contains('archive_visible.md')), isTrue);
      expect(buildFolderTree(docs).any((n) => n.label == 'Import'), isTrue);
    });

    testWidgets('archive list panel shows loading empty error ready states', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveListPanel(
              state: ArchiveListPanelState.loading,
              documents: const [],
              syncStates: const {},
              selectedId: null,
              onSelect: (_) {},
              onCreateDocument: () {},
              onRefresh: () {},
            ),
          ),
        ),
      );
      expect(find.text('문서 목록을 불러오는 중입니다'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveListPanel(
              state: ArchiveListPanelState.empty,
              documents: const [],
              syncStates: const {},
              selectedId: null,
              onSelect: (_) {},
              onCreateDocument: () {},
              onRefresh: () {},
            ),
          ),
        ),
      );
      expect(find.text('등록된 문서가 없습니다'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveListPanel(
              state: ArchiveListPanelState.error,
              documents: const [],
              syncStates: const {},
              selectedId: null,
              errorMessage: 'db locked',
              onSelect: (_) {},
              onCreateDocument: () {},
              onRefresh: () {},
            ),
          ),
        ),
      );
      expect(find.text('문서 목록을 불러오지 못했습니다'), findsOneWidget);
      expect(find.text('db locked'), findsOneWidget);

      final doc = DocumentMetadata(
        id: 'doc-1',
        path: 'documents/Import/sample.md',
        title: 'Sample',
        status: DocumentStatus.active,
        createdAt: DateTime.utc(2026, 6, 9),
        updatedAt: DateTime.utc(2026, 6, 9),
        contentHash: 'hash-sample',
        revision: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveListPanel(
              state: ArchiveListPanelState.ready,
              documents: [doc],
              syncStates: const {},
              selectedId: null,
              onSelect: (_) {},
              onCreateDocument: () {},
              onRefresh: () {},
            ),
          ),
        ),
      );
      expect(find.text('Sample'), findsOneWidget);
      expect(find.text('목록 1건'), findsOneWidget);
    });
  });
}

class _EmptyScanImportService implements DocumentImportService {
  @override
  Future<ImportDryRunResult> dryRun(DocumentImportOptions options) async {
    return const ImportDryRunResult(
      candidates: [],
      readyCount: 0,
      skipCount: 0,
      conflictCount: 0,
      duplicateCount: 0,
      invalidCount: 0,
    );
  }

  @override
  Future<ImportDryRunResult> scanWorkspaceOrphans(DocumentImportOptions options) => dryRun(options);

  @override
  Future<ImportDryRunResult> scanPaths(List<String> absolutePaths, DocumentImportOptions options) =>
      dryRun(options);

  @override
  Future<ImportExecutionResult> executeImport(DocumentImportOptions options) =>
      throw UnimplementedError();

  @override
  Future<ImportExecutionResult> executeApprovedImport(ImportApprovedSnapshot snapshot) =>
      throw UnimplementedError();
}

class _SkipOnlyImportService implements DocumentImportService {
  static const _preview = ImportDryRunResult(
    candidates: [
      ImportCandidate(
        relativePath: 'documents/Dev/skip.md',
        title: 'skip',
        categoryPath: 'Dev',
        contentHash: 'hash',
        status: ImportCandidateStatus.skipRegistered,
        message: 'Already registered',
      ),
    ],
    readyCount: 0,
    skipCount: 1,
    conflictCount: 0,
    duplicateCount: 0,
    invalidCount: 0,
  );

  @override
  Future<ImportDryRunResult> dryRun(DocumentImportOptions options) async => _preview;

  @override
  Future<ImportDryRunResult> scanWorkspaceOrphans(DocumentImportOptions options) => dryRun(options);

  @override
  Future<ImportDryRunResult> scanPaths(List<String> absolutePaths, DocumentImportOptions options) =>
      dryRun(options);

  @override
  Future<ImportExecutionResult> executeImport(DocumentImportOptions options) =>
      throw UnimplementedError();

  @override
  Future<ImportExecutionResult> executeApprovedImport(ImportApprovedSnapshot snapshot) =>
      throw UnimplementedError();
}

class _ReadyImportService implements DocumentImportService {
  static const _preview = ImportDryRunResult(
    candidates: [
      ImportCandidate(
        relativePath: 'documents/Import/ready.md',
        title: 'ready',
        categoryPath: 'Import',
        contentHash: 'hash',
        status: ImportCandidateStatus.copyRequired,
      ),
    ],
    readyCount: 1,
    skipCount: 0,
    conflictCount: 0,
    duplicateCount: 0,
    invalidCount: 0,
  );

  @override
  Future<ImportDryRunResult> dryRun(DocumentImportOptions options) async => _preview;

  @override
  Future<ImportDryRunResult> scanWorkspaceOrphans(DocumentImportOptions options) => dryRun(options);

  @override
  Future<ImportDryRunResult> scanPaths(List<String> absolutePaths, DocumentImportOptions options) =>
      dryRun(options);

  @override
  Future<ImportExecutionResult> executeImport(DocumentImportOptions options) =>
      throw UnimplementedError();

  @override
  Future<ImportExecutionResult> executeApprovedImport(ImportApprovedSnapshot snapshot) =>
      throw UnimplementedError();
}

class _FailingImportService implements DocumentImportService {
  @override
  Future<ImportDryRunResult> dryRun(DocumentImportOptions options) async {
    throw StateError('mock scan failure');
  }

  @override
  Future<ImportDryRunResult> scanWorkspaceOrphans(DocumentImportOptions options) => dryRun(options);

  @override
  Future<ImportDryRunResult> scanPaths(List<String> absolutePaths, DocumentImportOptions options) =>
      dryRun(options);

  @override
  Future<ImportExecutionResult> executeImport(DocumentImportOptions options) =>
      throw UnimplementedError();

  @override
  Future<ImportExecutionResult> executeApprovedImport(ImportApprovedSnapshot snapshot) =>
      throw UnimplementedError();
}
