// public_lumi_gc_service.dart — 만료 public_lumi capsule 물리 삭제 GC

import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/database_service_impl.dart';
import '../db/sqlite_write_guard.dart';
import '../platform/path_adapter.dart';
import '../relay/relay_journal_events.dart';
import '../sync/relay_journal_service.dart';

/// 만료된 Lumi Context Capsule export를 정리한다.
class PublicLumiGcService {
  final DatabaseServiceImpl _databaseService;
  final RelayJournalService _journalService;
  final SqliteWriteGuard _writeGuard;
  final Uuid _uuid = const Uuid();

  PublicLumiGcService({
    required DatabaseServiceImpl databaseService,
    required RelayJournalService journalService,
    SqliteWriteGuard? writeGuard,
  })  : _databaseService = databaseService,
        _journalService = journalService,
        _writeGuard = writeGuard ?? SqliteWriteGuard();

  Database get _db => _databaseService.requireDatabase();

  /// 만료 capsule을 스캔하고 물리 삭제한다 (원본 SAC 문서는 삭제하지 않음).
  Future<int> runGc({required String workspaceRoot}) async {
    return _writeGuard.run(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = await _db.query(
        'public_lumi_capsules',
        where: "status = 'active' AND expires_at <= ?",
        whereArgs: [now],
      );

      var deleted = 0;
      for (final row in rows) {
        final capsuleId = row['capsule_id'] as String;
        final exportRoot = row['export_root_path'] as String? ??
            resolvePublicLumiExportRoot(workspaceRoot);
        final capsuleDir = Directory(publicLumiCapsuleDirectory(exportRoot, capsuleId));

        await _journalService.appendRelayEvent(
          action: RelayJournalEvents.capsuleExpired,
          actor: 'gc',
          payload: {'capsule_id': capsuleId},
          idempotencyKey: 'capsule_expired:$capsuleId:$now',
        );

        try {
          if (await capsuleDir.exists()) {
            await capsuleDir.delete(recursive: true);
          }
          await _db.update(
            'public_lumi_capsules',
            {
              'status': 'deleted',
              'deleted_at': now,
            },
            where: 'capsule_id = ?',
            whereArgs: [capsuleId],
          );
          await _journalService.appendRelayEvent(
            action: RelayJournalEvents.capsuleDeleted,
            actor: 'gc',
            payload: {'capsule_id': capsuleId},
            idempotencyKey: 'capsule_deleted:$capsuleId',
          );
          deleted++;
        } catch (e) {
          await _journalService.appendRelayEvent(
            action: RelayJournalEvents.capsuleDeleteFailed,
            actor: 'gc',
            note: 'capsule_delete_failed: $e',
            payload: {'capsule_id': capsuleId},
            idempotencyKey: 'capsule_delete_failed:$capsuleId:${DateTime.now().millisecondsSinceEpoch}',
          );
        }
      }
      return deleted;
    });
  }

  /// capsule 메타데이터를 등록한다.
  Future<void> registerCapsule({
    required String workspaceRoot,
    required String capsuleId,
    required DateTime expiresAt,
    required String bodyPolicy,
    required String sensitivityPolicy,
    required String exportMode,
    Map<String, dynamic>? manifest,
    String? configuredExportRoot,
  }) async {
    await _writeGuard.run(() async {
      final exportRoot = configuredExportRoot?.trim().isNotEmpty == true
          ? configuredExportRoot!.trim()
          : resolvePublicLumiExportRoot(workspaceRoot);
      final now = DateTime.now().toUtc().toIso8601String();
      await _db.insert('public_lumi_capsules', {
        'id': _uuid.v4(),
        'capsule_id': capsuleId,
        'export_root_path': exportRoot,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'body_policy': bodyPolicy,
        'sensitivity_policy': sensitivityPolicy,
        'export_mode': exportMode,
        'status': 'active',
        'manifest_json': manifest == null ? null : jsonEncode(manifest),
        'created_at': now,
      });
      await _journalService.appendRelayEvent(
        action: RelayJournalEvents.capsuleCreated,
        actor: 'relay',
        payload: {
          'capsule_id': capsuleId,
          'expires_at': expiresAt.toUtc().toIso8601String(),
          'body_policy': bodyPolicy,
        },
        idempotencyKey: 'capsule_created:$capsuleId',
      );
      await _journalService.appendRelayEvent(
        action: RelayJournalEvents.publicExportCreated,
        actor: 'relay',
        payload: {'capsule_id': capsuleId, 'export_root': exportRoot},
        idempotencyKey: 'public_export_created:$capsuleId',
      );
    });
  }
}
