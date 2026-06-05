// sync_journal_writer.dart — sync_journal append-only 기록

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../platform/path_adapter.dart';

class SyncJournalWriter {
  final Database _db;
  final String _workspaceRoot;
  final Uuid _uuid = const Uuid();

  SyncJournalWriter({
    required Database db,
    required String workspaceRoot,
  })  : _db = db,
        _workspaceRoot = workspaceRoot;

  /// sync_journal 테이블과 파일 로그에 이벤트를 append한다.
  Future<void> append({
    required String documentId,
    required String actor,
    required String action,
    int? revision,
    String? note,
  }) async {
    final occurredAt = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();

    await _db.insert('sync_journal', {
      'id': id,
      'document_id': documentId,
      'actor': actor,
      'action': action,
      'revision': revision,
      'note': note,
      'occurred_at': occurredAt,
    });

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
        'revision': revision,
        'note': note,
        'occurred_at': occurredAt,
      }),
      encoding: utf8,
      flush: true,
    );
  }
}
