// sprint16h2_integration_test.dart — Sprint 16H-2 Dry-run Input + Git Repo Save hotfix

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/domain/models/document_import.dart';
import 'package:sac_app/domain/services/document_import_service.dart';
import 'package:sac_app/ui/screens/file_import_screen.dart';

void main() {
  group('sprint16h2 integration', () {
    late Directory tempDir;
    late SacContainer container;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sac_sprint16h2_test_');
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
        name: 'Sprint16H2 WS',
        rootPath: p.join(tempDir.path, 'SAC S16H2'),
      );
      await container.bindWorkspace(workspace);
    }

    test('git repo url saves and survives reload', () async {
      await bindWorkspace();
      final current = await container.settingsService.getSettings();
      const url = 'https://github.com/owner/svil-archive-core.git';
      await container.settingsService.saveSettings(
        current.copyWith(
          gitSync: current.gitSync.copyWith(repoUrl: url, branch: 'main'),
        ),
      );
      final reloaded = await container.settingsService.getSettings();
      expect(reloaded.gitSync.repoUrl, url);
      expect(reloaded.gitSync.branch, 'main');
    });

    test('git repo url preserved when enabling sync without clearing url', () async {
      await bindWorkspace();
      final current = await container.settingsService.getSettings();
      const url = 'https://github.com/owner/repo.git';
      final withUrl = current.gitSync.copyWith(repoUrl: url, enabled: false);
      await container.settingsService.saveSettings(current.copyWith(gitSync: withUrl));

      final toggled = withUrl.copyWith(enabled: true);
      await container.settingsService.saveSettings(current.copyWith(gitSync: toggled));

      final reloaded = await container.settingsService.getSettings();
      expect(reloaded.gitSync.enabled, isTrue);
      expect(reloaded.gitSync.repoUrl, url);
    });

    test('import fingerprint invalidates when options change after dry-run', () async {
      await bindWorkspace();
      const rel = 'documents/Dev/fp_s16h2.md';
      final root = container.activeWorkspace!.rootPath;
      final file = File(p.join(root, rel));
      await file.parent.create(recursive: true);
      await file.writeAsString('# fp\n\nbody');

      final baseOptions = DocumentImportOptions(
        absolutePaths: [file.path],
        includeSubfolders: true,
      );
      final preview = await container.documentImportService.dryRun(baseOptions);
      final snapshot = ImportApprovedSnapshot(
        options: baseOptions.copyWith(dryRunOnly: false),
        preview: preview,
      );
      expect(snapshot.fingerprint, baseOptions.fingerprint);

      final changed = baseOptions.copyWith(includeSubfolders: false);
      expect(changed.fingerprint, isNot(snapshot.fingerprint));
    });

    test('stale snapshot fingerprint blocks execute at UI policy level', () async {
      await bindWorkspace();
      const rel = 'documents/Dev/mismatch_s16h2.md';
      final root = container.activeWorkspace!.rootPath;
      final file = File(p.join(root, rel));
      await file.parent.create(recursive: true);
      await file.writeAsString('# mismatch\n\nbody');

      final options = DocumentImportOptions(absolutePaths: [file.path]);
      final preview = await container.documentImportService.dryRun(options);
      final snapshot = ImportApprovedSnapshot(
        options: options.copyWith(dryRunOnly: false),
        preview: preview,
      );
      final changed = options.copyWith(includeSubfolders: false);

      expect(snapshot.options.fingerprint, options.fingerprint);
      expect(changed.fingerprint, isNot(snapshot.options.fingerprint));
    });

    testWidgets('dry-run success keeps option switches enabled', (tester) async {
      final mock = _MockDocumentImportService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileImportScreen(importService: mock),
          ),
        ),
      );

      await tester.tap(find.text('Workspace orphan 스캔'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      final switches = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
      expect(switches.every((tile) => tile.onChanged != null), isTrue);
      expect(find.textContaining('Dry-run 결과: 후보 1'), findsOneWidget);
    });

    testWidgets('dry-run failure restores option switches', (tester) async {
      final mock = _MockDocumentImportService(failDryRun: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileImportScreen(importService: mock),
          ),
        ),
      );

      await tester.tap(find.text('Workspace orphan 스캔'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      final switches = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
      expect(switches.every((tile) => tile.onChanged != null), isTrue);
      expect(find.text('Dry-run 오류'), findsOneWidget);
    });

    testWidgets('dry-run failure after prior success clears stale execute snapshot', (tester) async {
      final mock = _MockDocumentImportService(failAfterSuccess: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileImportScreen(importService: mock),
          ),
        ),
      );

      await tester.tap(find.text('Workspace orphan 스캔'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Dry-run 결과: 후보 1'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Workspace orphan 스캔'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Workspace orphan 스캔'));
      await tester.pumpAndSettle();

      final executeButton = find.widgetWithText(ElevatedButton, '정식 등록 실행');
      expect(tester.widget<ElevatedButton>(executeButton).onPressed, isNull);
      expect(find.textContaining('등록 가능 1'), findsNothing);
      expect(find.text('Dry-run 오류'), findsOneWidget);
    });

    testWidgets('option change after dry-run disables execute until re-run', (tester) async {
      final mock = _MockDocumentImportService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileImportScreen(importService: mock),
          ),
        ),
      );

      await tester.tap(find.text('Workspace orphan 스캔'));
      await tester.pumpAndSettle();

      final executeButton = find.widgetWithText(ElevatedButton, '정식 등록 실행');
      final executeBefore = tester.widget<ElevatedButton>(executeButton);
      expect(executeBefore.onPressed, isNotNull);

      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder.first);
      await tester.pumpAndSettle();

      final executeAfter = tester.widget<ElevatedButton>(executeButton);
      expect(executeAfter.onPressed, isNull);
      expect(find.text('Dry-run 결과 (재검사 필요)'), findsOneWidget);
      expect(
        find.text('옵션 또는 경로가 변경되었습니다. 미리 검사를 다시 실행하세요.'),
        findsOneWidget,
      );
    });
  });
}

/// File Import 화면 위젯 테스트용 mock 서비스.
class _MockDocumentImportService implements DocumentImportService {
  final bool failDryRun;
  final bool failAfterSuccess;
  var _dryRunCalls = 0;

  _MockDocumentImportService({
    this.failDryRun = false,
    this.failAfterSuccess = false,
  });

  static const _preview = ImportDryRunResult(
    candidates: [
      ImportCandidate(
        relativePath: 'documents/Dev/mock.md',
        title: 'mock',
        categoryPath: 'Dev',
        contentHash: 'hash',
        status: ImportCandidateStatus.ready,
      ),
    ],
    readyCount: 1,
    skipCount: 0,
    conflictCount: 0,
    duplicateCount: 0,
    invalidCount: 0,
  );

  @override
  Future<ImportDryRunResult> dryRun(DocumentImportOptions options) async {
    _dryRunCalls += 1;
    if (failDryRun) {
      throw StateError('mock dry-run failure');
    }
    if (failAfterSuccess && _dryRunCalls > 1) {
      throw StateError('mock dry-run failure after success');
    }
    return _preview;
  }

  @override
  Future<ImportDryRunResult> scanWorkspaceOrphans(DocumentImportOptions options) =>
      dryRun(options);

  @override
  Future<ImportDryRunResult> scanPaths(
    List<String> absolutePaths,
    DocumentImportOptions options,
  ) =>
      dryRun(options);

  @override
  Future<ImportExecutionResult> executeImport(DocumentImportOptions options) {
    throw UnimplementedError();
  }

  @override
  Future<ImportExecutionResult> executeApprovedImport(ImportApprovedSnapshot snapshot) {
    throw UnimplementedError();
  }
}
