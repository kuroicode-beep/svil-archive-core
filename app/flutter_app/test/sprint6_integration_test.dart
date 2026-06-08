// sprint6_integration_test.dart — Dashboard / Privacy / LLM export / Local AI 테스트

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/services/ollama_adapter.dart';
import 'package:sac_app/domain/models/dashboard.dart';
import 'package:sac_app/domain/models/personal_archive.dart';

void main() {
  late Directory tempDir;
  late SacContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sac_sprint6_test_');
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
      name: 'Sprint6 WS',
      rootPath: p.join(tempDir.path, 'SAC S6'),
    );
    await container.bindWorkspace(workspace);
  }

  test('dashboard service builds summary from database', () async {
    await bindWorkspace();
    final summary = await container.dashboardService.getDashboardSummary();
    expect(summary.documentCount, greaterThanOrEqualTo(0));
    expect(summary.aiCollaboration.lastCompletedSprint, contains('Sprint'));
  });

  test('privacy service builds summary with external transfer disabled', () async {
    await bindWorkspace();
    final privacy = await container.privacyService.getPrivacySummary();
    expect(privacy.localProcessingEnabled, isTrue);
    expect(privacy.externalTransferEnabled, isFalse);
    expect(privacy.exportPolicyLabel, contains('active'));
  });

  test('llm self-info export includes only active archive items', () async {
    await bindWorkspace();
    final archive = container.personalArchiveService;
    final queue = container.extractionQueueService;
    final export = container.llmSelfInfoExportService;

    await archive.createManualItem(
      const CreatePersonalArchiveItemInput(
        itemType: 'profile',
        title: '이름',
        content: 'ACTIVE_ONLY',
      ),
    );

    final deleted = await archive.createManualItem(
      const CreatePersonalArchiveItemInput(
        itemType: 'project',
        title: '삭제될 항목',
        content: 'SHOULD_NOT_EXPORT',
      ),
    );
    await archive.deleteItem(deleted.id);

    await queue.enqueueCandidate(
      const CreateExtractionCandidateInput(
        candidateType: 'approved',
        candidateTitle: 'pending',
        candidateContent: 'PENDING_SHOULD_NOT_EXPORT',
      ),
    );
    final rejected = await queue.enqueueCandidate(
      const CreateExtractionCandidateInput(
        candidateType: 'approved',
        candidateTitle: 'reject',
        candidateContent: 'REJECTED_SHOULD_NOT_EXPORT',
      ),
    );
    await queue.rejectCandidate(rejected.id);

    final result = await export.buildPreview();
    expect(result.previewMarkdown.contains('ACTIVE_ONLY'), isTrue);
    expect(result.previewMarkdown.contains('SHOULD_NOT_EXPORT'), isFalse);
    expect(result.previewMarkdown.contains('PENDING_SHOULD_NOT_EXPORT'), isFalse);
    expect(result.previewMarkdown.contains('REJECTED_SHOULD_NOT_EXPORT'), isFalse);
    expect(result.includedItemCount, 1);
    expect(result.excludedPendingCount, greaterThanOrEqualTo(1));
    expect(result.excludedRejectedCount, greaterThanOrEqualTo(1));
    expect(result.excludedDeletedCount, greaterThanOrEqualTo(1));
  });

  test('export audit log does not store personal content body', () async {
    await bindWorkspace();
    final archive = container.personalArchiveService;
    await archive.createManualItem(
      const CreatePersonalArchiveItemInput(
        itemType: 'profile',
        title: '비밀',
        content: 'SECRET_EXPORT_BODY',
      ),
    );
    await container.llmSelfInfoExportService.exportToFile();

    final db = container.databaseService.requireDatabase();
    final logs = await db.query(
      'audit_logs',
      where: "action = 'export'",
      orderBy: 'occurred_at DESC',
      limit: 3,
    );
    final serialized = logs.map((r) => r.toString()).join('\n');
    expect(serialized.contains('SECRET_EXPORT_BODY'), isFalse);
  });

  test('local ai service returns offline status safely when ollama unavailable', () async {
    final service = OllamaAdapter(
      baseUrl: 'http://127.0.0.1:59999',
      timeout: const Duration(milliseconds: 200),
    );
    final status = await service.checkStatus();
    expect(status.state, isNot(LocalAiConnectionState.connected));
    expect(status.label, isNotEmpty);
    final models = await service.listModels();
    expect(models, isEmpty);
  });

  test('sprint 05 approve atomicity regression remains intact', () async {
    await bindWorkspace();
    final queue = container.extractionQueueService;
    final archive = container.personalArchiveService;

    final candidate = await queue.enqueueCandidate(
      const CreateExtractionCandidateInput(
        candidateType: 'approved',
        candidateTitle: '회귀',
        candidateContent: 'atomic',
      ),
    );
    await queue.approveCandidate(candidate.id);
    expect(
      () => queue.approveCandidate(candidate.id),
      throwsA(isA<StateError>()),
    );
    expect((await archive.listItems()).length, 1);
  });
}
