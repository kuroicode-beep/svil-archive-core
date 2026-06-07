// sprint5_integration_test.dart — Personal Archive / Extraction Queue 통합 테스트

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/data/db/migrations.dart';
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
    tempDir = await Directory.systemTemp.createTemp('sac_sprint5_test_');
    container = await SacContainer.create(registryDirectory: tempDir.path);
  });

  tearDown(() async {
    await container.databaseService.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> bindWorkspace() async {
    final workspace = await container.workspaceService.createWorkspace(
      name: 'Sprint5 WS',
      rootPath: p.join(tempDir.path, 'SAC S5'),
    );
    await container.bindWorkspace(workspace);
  }

  test('migration v5 creates work queue and MCP tables', () async {
    await bindWorkspace();
    final version = await container.databaseService.getSchemaVersion();
    expect(version, kSacSchemaVersion);
    final db = container.databaseService.requireDatabase();
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final names = tables.map((r) => r['name'] as String).toSet();
    expect(names.contains('personal_archive_items'), isTrue);
    expect(names.contains('personal_extraction_queue'), isTrue);
    expect(names.contains('journal_comments'), isTrue);
    expect(names.contains('work_queue_tickets'), isTrue);
    expect(names.contains('mcp_tool_settings'), isTrue);
    expect(names.contains('permission_tokens'), isTrue);
  });

  test('manual personal archive item create update delete', () async {
    await bindWorkspace();
    final service = container.personalArchiveService;

    final created = await service.createManualItem(
      const CreatePersonalArchiveItemInput(
        itemType: 'profile',
        title: '이름',
        content: '테스트 사용자',
      ),
    );
    expect(created.status, PersonalArchiveItemStatus.active);

    final updated = await service.updateItem(
      UpdatePersonalArchiveItemInput(
        id: created.id,
        title: '이름(수정)',
        content: '수정된 내용',
      ),
    );
    expect(updated.title, '이름(수정)');

    await service.deleteItem(created.id);
    final items = await service.listItems();
    expect(items.any((i) => i.id == created.id), isFalse);
  });

  test('pending candidate approve moves to personal archive', () async {
    await bindWorkspace();
    final queue = container.extractionQueueService;
    final archive = container.personalArchiveService;

    final candidate = await queue.enqueueCandidate(
      const CreateExtractionCandidateInput(
        candidateType: 'approved',
        candidateTitle: '취미',
        candidateContent: '독서',
        confidence: 0.8,
      ),
    );
    expect(candidate.status, ExtractionQueueStatus.pending);

    final before = await archive.listItems();
    final item = await queue.approveCandidate(candidate.id);
    final after = await archive.listItems();

    expect(after.length, before.length + 1);
    expect(item.title, '취미');
    expect(item.content, '독서');

    final all = await queue.listAllCandidates();
    expect(
      all.firstWhere((c) => c.id == candidate.id).status,
      ExtractionQueueStatus.approved,
    );
  });

  test('edit and approve stores modified content', () async {
    await bindWorkspace();
    final queue = container.extractionQueueService;

    final candidate = await queue.enqueueCandidate(
      const CreateExtractionCandidateInput(
        candidateType: 'approved',
        candidateTitle: '원본',
        candidateContent: '원본 내용',
      ),
    );

    final item = await queue.editAndApproveCandidate(
      EditExtractionCandidateInput(
        candidateId: candidate.id,
        title: '수정본',
        content: '수정된 내용',
      ),
    );
    expect(item.title, '수정본');
    expect(item.content, '수정된 내용');
  });

  test('reject does not create personal archive item', () async {
    await bindWorkspace();
    final queue = container.extractionQueueService;
    final archive = container.personalArchiveService;

    final candidate = await queue.enqueueCandidate(
      const CreateExtractionCandidateInput(
        candidateType: 'approved',
        candidateTitle: '거절 대상',
        candidateContent: '민감 데이터',
      ),
    );

    final beforeCount = (await archive.listItems()).length;
    await queue.rejectCandidate(candidate.id);
    final afterCount = (await archive.listItems()).length;

    expect(afterCount, beforeCount);
    final all = await queue.listAllCandidates();
    expect(
      all.firstWhere((c) => c.id == candidate.id).status,
      ExtractionQueueStatus.rejected,
    );
  });

  test('audit log does not store personal content body', () async {
    await bindWorkspace();
    final queue = container.extractionQueueService;
    final candidate = await queue.enqueueCandidate(
      const CreateExtractionCandidateInput(
        candidateType: 'profile',
        candidateTitle: '비밀',
        candidateContent: 'SECRET_PII_VALUE',
      ),
    );
    await queue.approveCandidate(candidate.id);

    final db = container.databaseService.requireDatabase();
    final logs = await db.query('audit_logs', orderBy: 'occurred_at DESC', limit: 5);
    final serialized = logs.map((r) => r.toString()).join('\n');
    expect(serialized.contains('SECRET_PII_VALUE'), isFalse);
  });

  test('second approve on same candidate fails with single archive item', () async {
    await bindWorkspace();
    final queue = container.extractionQueueService;
    final archive = container.personalArchiveService;

    final candidate = await queue.enqueueCandidate(
      const CreateExtractionCandidateInput(
        candidateType: 'approved',
        candidateTitle: '중복 승인',
        candidateContent: '한 번만 저장',
      ),
    );

    await queue.approveCandidate(candidate.id);
    expect(
      () => queue.approveCandidate(candidate.id),
      throwsA(isA<StateError>()),
    );
    expect((await archive.listItems()).length, 1);
  });

  test('concurrent approve and edit approve create only one archive item', () async {
    await bindWorkspace();
    final queue = container.extractionQueueService;
    final archive = container.personalArchiveService;

    final candidate = await queue.enqueueCandidate(
      const CreateExtractionCandidateInput(
        candidateType: 'approved',
        candidateTitle: '동시 처리',
        candidateContent: '원본',
      ),
    );

    Object? approveError;
    Object? editError;

    Future<void> runApprove() async {
      try {
        await queue.approveCandidate(candidate.id);
      } catch (e) {
        approveError = e;
      }
    }

    Future<void> runEditApprove() async {
      try {
        await queue.editAndApproveCandidate(
          EditExtractionCandidateInput(
            candidateId: candidate.id,
            title: '수정본',
            content: '수정',
          ),
        );
      } catch (e) {
        editError = e;
      }
    }

    await Future.wait([runApprove(), runEditApprove()]);

    expect((await archive.listItems()).length, 1);
    expect(approveError != null || editError != null, isTrue);
  });

  test('second reject on same candidate fails', () async {
    await bindWorkspace();
    final queue = container.extractionQueueService;

    final candidate = await queue.enqueueCandidate(
      const CreateExtractionCandidateInput(
        candidateType: 'approved',
        candidateTitle: '거절 중복',
        candidateContent: '내용',
      ),
    );

    await queue.rejectCandidate(candidate.id);
    expect(
      () => queue.rejectCandidate(candidate.id),
      throwsA(isA<StateError>()),
    );
  });

  test('journal comment create and list', () async {
    await bindWorkspace();
    final journal = container.journalCommentService;
    await journal.createComment(
      const CreateJournalCommentInput(
        title: '오늘',
        content: '좋은 하루',
        mood: 'happy',
        tags: ['daily'],
      ),
    );
    final list = await journal.listComments();
    expect(list, isNotEmpty);
    expect(list.first.title, '오늘');
  });
}
