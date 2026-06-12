// relay_queue_service_impl.dart — Relay Queue SQLite 구현

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/relay_queue_item.dart';
import '../../domain/services/relay_queue_service.dart';
import '../db/database_service_impl.dart';
import '../db/sqlite_write_guard.dart';
import '../relay/relay_journal_events.dart';
import '../sync/relay_journal_service.dart';

class RelayQueueServiceImpl implements RelayQueueService {
  final DatabaseServiceImpl _databaseService;
  final RelayJournalService _journalService;
  final SqliteWriteGuard _writeGuard;
  final Uuid _uuid = const Uuid();

  RelayQueueServiceImpl({
    required DatabaseServiceImpl databaseService,
    required RelayJournalService journalService,
    SqliteWriteGuard? writeGuard,
  })  : _databaseService = databaseService,
        _journalService = journalService,
        _writeGuard = writeGuard ?? SqliteWriteGuard();

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<RelayQueueItem> enqueueTask({
    String? sourceImportQueueId,
    String? sourceDocumentId,
    required String targetAgent,
    String? eventType,
    String? project,
    int priority = 5,
    String? notice,
  }) async {
    return _writeGuard.run(() async {
      final now = DateTime.now().toUtc();
      final id = _uuid.v4();
      await _db.insert('relay_queue', {
        'id': id,
        'source_import_queue_id': sourceImportQueueId,
        'source_document_id': sourceDocumentId,
        'target_agent': targetAgent,
        'event_type': eventType,
        'project': project,
        'priority': priority,
        'status': RelayQueueStatus.pending.name,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'notice': notice,
      });

      await _journalService.appendRelayEvent(
        action: RelayJournalEvents.relayTaskCreated,
        actor: 'relay',
        documentId: sourceDocumentId ?? kRelaySystemDocumentId,
        payload: {
          'relay_queue_id': id,
          'target_agent': targetAgent,
          'event_type': eventType,
        },
        idempotencyKey: 'relay_task_created:$id',
      );

      final item = await findById(id);
      if (item == null) {
        throw StateError('relay_queue insert failed: $id');
      }
      return item;
    });
  }

  @override
  Future<void> updateStatus(
    String id,
    RelayQueueStatus status, {
    String? resultDocumentId,
    String? errorMessage,
  }) async {
    await _writeGuard.run(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      final values = <String, Object?>{
        'status': status.name,
        'updated_at': now,
      };
      if (resultDocumentId != null) {
        values['result_document_id'] = resultDocumentId;
      }
      if (errorMessage != null) {
        values['error_message'] = errorMessage;
      }
      if (status == RelayQueueStatus.running) {
        values['started_at'] = now;
      }
      if (status == RelayQueueStatus.done || status == RelayQueueStatus.failed) {
        values['completed_at'] = now;
      }

      await _db.update('relay_queue', values, where: 'id = ?', whereArgs: [id]);

      final journalAction = switch (status) {
        RelayQueueStatus.running => RelayJournalEvents.relayTaskStarted,
        RelayQueueStatus.done => RelayJournalEvents.relayTaskCompleted,
        RelayQueueStatus.failed => RelayJournalEvents.relayTaskFailed,
        _ => null,
      };
      if (journalAction != null) {
        await _journalService.appendRelayEvent(
          action: journalAction,
          actor: 'relay',
          documentId: kRelaySystemDocumentId,
          payload: {
            'relay_queue_id': id,
            'status': status.name,
            'error': ?errorMessage,
          },
          idempotencyKey: '$journalAction:$id:${status.name}',
        );
      }
    });
  }

  @override
  Future<List<RelayQueueItem>> listItems({List<RelayQueueStatus>? statuses}) async {
    final List<Map<String, Object?>> rows;
    if (statuses == null || statuses.isEmpty) {
      rows = await _db.query('relay_queue', orderBy: 'created_at DESC');
    } else {
      final placeholders = List.filled(statuses.length, '?').join(',');
      rows = await _db.query(
        'relay_queue',
        where: 'status IN ($placeholders)',
        whereArgs: statuses.map((s) => s.name).toList(),
        orderBy: 'created_at DESC',
      );
    }
    return rows.map(RelayQueueItem.fromRow).toList();
  }

  @override
  Future<RelayQueueItem?> findById(String id) async {
    final rows = await _db.query(
      'relay_queue',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return RelayQueueItem.fromRow(rows.first);
  }
}
