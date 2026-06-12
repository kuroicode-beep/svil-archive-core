// relay_journal_service.dart — relay event용 sync_journal 확장 기록

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/database_service_impl.dart';
import '../db/sqlite_write_guard.dart';
import '../platform/path_adapter.dart';
import '../relay/relay_idempotency_service.dart';
import '../relay/relay_journal_events.dart';

/// relay 이벤트를 sync_journal + 파일 로그에 기록한다.
class RelayJournalService {
  final DatabaseServiceImpl _databaseService;
  final String _workspaceRoot;
  final RelayIdempotencyService _idempotencyService;
  final SqliteWriteGuard _writeGuard;
  final Uuid _uuid = const Uuid();

  RelayJournalService({
    required DatabaseServiceImpl databaseService,
    required String workspaceRoot,
    required RelayIdempotencyService idempotencyService,
    SqliteWriteGuard? writeGuard,
  })  : _databaseService = databaseService,
        _workspaceRoot = workspaceRoot,
        _idempotencyService = idempotencyService,
        _writeGuard = writeGuard ?? SqliteWriteGuard();

  Database get _db => _databaseService.requireDatabase();

  /// relay 이벤트를 idempotency와 함께 journal에 append한다.
  Future<void> appendRelayEvent({
    required String action,
    required String actor,
    String documentId = kRelaySystemDocumentId,
    String? note,
    Map<String, dynamic>? payload,
    String? idempotencyKey,
  }) async {
    await _writeGuard.run(() async {
      if (idempotencyKey != null) {
        final registered = await _idempotencyService.registerIfAbsent(
          idempotencyKey: idempotencyKey,
          eventType: action,
          resultRef: documentId,
        );
        if (!registered) return;
      }

      final occurredAt = DateTime.now().toUtc().toIso8601String();
      final id = _uuid.v4();
      final payloadJson = payload == null ? null : jsonEncode(payload);

      try {
        await _db.insert('sync_journal', {
          'id': id,
          'document_id': documentId,
          'actor': actor,
          'action': action,
          'note': note,
          'occurred_at': occurredAt,
          'idempotency_key': idempotencyKey,
          'payload_json': payloadJson,
        });
      } catch (e) {
        throw StateError('sync_journal relay append failed: $e');
      }

      final journalDir = Directory(syncJournalDirectoryPath(_workspaceRoot));
      if (!await journalDir.exists()) {
        await journalDir.create(recursive: true);
      }
      final safeStamp = occurredAt.replaceAll(':', '-');
      final logFile = File(p.join(journalDir.path, '$safeStamp-$id.json'));
      await logFile.writeAsString(
        jsonEncode({
          'id': id,
          'document_id': documentId,
          'actor': actor,
          'action': action,
          'note': note,
          'occurred_at': occurredAt,
          'idempotency_key': idempotencyKey,
          'payload_json': payload,
        }),
        encoding: utf8,
        flush: true,
      );
    });
  }
}
