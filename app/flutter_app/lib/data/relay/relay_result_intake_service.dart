// relay_result_intake_service.dart — relay result 검증 및 manual rescue

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/database_service_impl.dart';
import '../db/sqlite_write_guard.dart';
import '../relay/relay_capability_token_service.dart';
import '../relay/relay_journal_events.dart';
import '../sync/relay_journal_service.dart';

/// relay result frontmatter 검증 결과.
class RelayResultIntakeOutcome {
  final bool accepted;
  final String? reviewId;
  final String? reason;

  const RelayResultIntakeOutcome({
    required this.accepted,
    this.reviewId,
    this.reason,
  });
}

/// relay result md intake 및 manual rescue inbox.
class RelayResultIntakeService {
  final DatabaseServiceImpl _databaseService;
  final RelayCapabilityTokenService _tokenService;
  final RelayJournalService _journalService;
  final SqliteWriteGuard _writeGuard;
  final Uuid _uuid = const Uuid();

  RelayResultIntakeService({
    required DatabaseServiceImpl databaseService,
    required RelayCapabilityTokenService tokenService,
    required RelayJournalService journalService,
    SqliteWriteGuard? writeGuard,
  })  : _databaseService = databaseService,
        _tokenService = tokenService,
        _journalService = journalService,
        _writeGuard = writeGuard ?? SqliteWriteGuard();

  Database get _db => _databaseService.requireDatabase();

  /// frontmatter map으로 relay result를 검증한다.
  Future<RelayResultIntakeOutcome> intakeResult({
    required Map<String, String> frontmatter,
    required String sourcePath,
  }) async {
    return _writeGuard.run(() async {
      final sacEvent = frontmatter['sac_event'] ?? '';
      if (sacEvent != 'relay_result') {
        return const RelayResultIntakeOutcome(
          accepted: false,
          reason: 'not_relay_result',
        );
      }

      final taskId = frontmatter['task_id'] ?? '';
      final token = frontmatter['capability_token'] ?? '';
      final resultType = frontmatter['result_type'] ?? '';
      final targetDocumentId = frontmatter['target_document_id'];
      final targetPath = frontmatter['target_path'];

      if (taskId.isEmpty || token.isEmpty || resultType.isEmpty) {
        return await _reject(
          taskId: taskId.isEmpty ? 'unknown' : taskId,
          sourcePath: sourcePath,
          reason: 'missing_required_fields',
        );
      }

      await _journalService.appendRelayEvent(
        action: RelayJournalEvents.relayResultReceived,
        actor: 'relay',
        payload: {'task_id': taskId, 'source_path': sourcePath},
        idempotencyKey: 'relay_result_received:$taskId:$sourcePath',
      );

      final valid = await _tokenService.validate(
        taskId: taskId,
        plainToken: token,
        resultType: resultType,
        targetDocumentId: targetDocumentId,
        targetPath: targetPath,
      );
      if (!valid) {
        return await _reject(
          taskId: taskId,
          sourcePath: sourcePath,
          reason: 'capability_token_invalid',
        );
      }

      await _tokenService.markConsumed(taskId);
      return const RelayResultIntakeOutcome(accepted: true);
    });
  }

  /// 검증 실패 결과를 review inbox에 격리한다.
  Future<RelayResultIntakeOutcome> _reject({
    required String taskId,
    required String sourcePath,
    required String reason,
  }) async {
    final reviewId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert('relay_result_reviews', {
      'id': reviewId,
      'task_id': taskId,
      'source_path': sourcePath,
      'status': 'pending_review',
      'reject_reason': reason,
      'created_at': now,
      'updated_at': now,
    });
    await _journalService.appendRelayEvent(
      action: RelayJournalEvents.relayResultRejected,
      actor: 'relay',
      payload: {
        'task_id': taskId,
        'review_id': reviewId,
        'reason': reason,
      },
      idempotencyKey: 'relay_result_rejected:$reviewId',
    );
    return RelayResultIntakeOutcome(
      accepted: false,
      reviewId: reviewId,
      reason: reason,
    );
  }

  /// 수동 구제를 승인한다.
  Future<void> approveManualRescue(String reviewId, {required String actor}) async {
    await _writeGuard.run(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      await _db.update(
        'relay_result_reviews',
        {'status': 'approved', 'updated_at': now},
        where: 'id = ?',
        whereArgs: [reviewId],
      );
      await _journalService.appendRelayEvent(
        action: RelayJournalEvents.manualRescueApproved,
        actor: actor,
        payload: {'review_id': reviewId},
        idempotencyKey: 'manual_rescue_approved:$reviewId',
      );
    });
  }

  /// 수동 구제를 거부한다.
  Future<void> rejectManualRescue(String reviewId, {required String actor}) async {
    await _writeGuard.run(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      await _db.update(
        'relay_result_reviews',
        {'status': 'rejected', 'updated_at': now},
        where: 'id = ?',
        whereArgs: [reviewId],
      );
      await _journalService.appendRelayEvent(
        action: RelayJournalEvents.manualRescueRejected,
        actor: actor,
        payload: {'review_id': reviewId},
        idempotencyKey: 'manual_rescue_rejected:$reviewId',
      );
    });
  }

  /// pending review 목록을 반환한다.
  Future<List<Map<String, Object?>>> listPendingReviews() async {
    return _db.query(
      'relay_result_reviews',
      where: "status = 'pending_review'",
      orderBy: 'created_at DESC',
    );
  }
}
