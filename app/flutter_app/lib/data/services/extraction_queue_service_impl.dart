// extraction_queue_service_impl.dart — 추출 대기열 SQLite 구현

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/personal_archive.dart';
import '../../domain/services/extraction_queue_service.dart';
import '../db/database_service_impl.dart';

class ExtractionQueueServiceImpl implements ExtractionQueueService {
  final DatabaseServiceImpl _databaseService;
  final Uuid _uuid = const Uuid();

  ExtractionQueueServiceImpl({
    required DatabaseServiceImpl databaseService,
  }) : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<List<ExtractionCandidate>> listPendingCandidates() async {
    final rows = await _db.query(
      'personal_extraction_queue',
      where: "status = ?",
      whereArgs: [ExtractionQueueStatus.pending.name],
      orderBy: 'created_at DESC',
    );
    return rows.map(_mapCandidate).toList();
  }

  @override
  Future<List<ExtractionCandidate>> listAllCandidates() async {
    final rows = await _db.query(
      'personal_extraction_queue',
      orderBy: 'created_at DESC',
    );
    return rows.map(_mapCandidate).toList();
  }

  @override
  Future<ExtractionCandidate> enqueueCandidate(CreateExtractionCandidateInput input) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert('personal_extraction_queue', {
      'id': id,
      'source_document_id': input.sourceDocumentId,
      'source_path': input.sourcePath,
      'candidate_type': input.candidateType,
      'candidate_title': input.candidateTitle,
      'candidate_content': input.candidateContent,
      'confidence': input.confidence,
      'reason': input.reason,
      'status': ExtractionQueueStatus.pending.name,
      'created_at': now,
      'updated_at': now,
    });
    await _audit('enqueue', id);
    return _mapCandidate({
      'id': id,
      'source_document_id': input.sourceDocumentId,
      'source_path': input.sourcePath,
      'candidate_type': input.candidateType,
      'candidate_title': input.candidateTitle,
      'candidate_content': input.candidateContent,
      'confidence': input.confidence,
      'reason': input.reason,
      'status': ExtractionQueueStatus.pending.name,
      'created_at': now,
      'updated_at': now,
    });
  }

  @override
  Future<PersonalArchiveItem> approveCandidate(String candidateId) async {
    return _db.transaction((txn) async {
      final candidate = await _claimPending(txn, candidateId, ExtractionQueueStatus.approved);
      final item = await _insertArchiveItem(
        txn,
        itemType: candidate.candidateType,
        title: candidate.candidateTitle,
        content: candidate.candidateContent,
        sourceDocumentId: candidate.sourceDocumentId,
        sourcePath: candidate.sourcePath,
        confidence: candidate.confidence,
      );
      await _auditInTransaction(txn, 'approve', candidateId);
      return item;
    });
  }

  @override
  Future<PersonalArchiveItem> editAndApproveCandidate(
    EditExtractionCandidateInput input,
  ) async {
    return _db.transaction((txn) async {
      final candidate = await _claimPending(
        txn,
        input.candidateId,
        ExtractionQueueStatus.editedApproved,
      );
      final item = await _insertArchiveItem(
        txn,
        itemType: input.itemType ?? candidate.candidateType,
        title: input.title,
        content: input.content,
        sourceDocumentId: candidate.sourceDocumentId,
        sourcePath: candidate.sourcePath,
        confidence: candidate.confidence,
      );
      await _auditInTransaction(txn, 'edit_approve', input.candidateId);
      return item;
    });
  }

  @override
  Future<void> rejectCandidate(String candidateId) async {
    await _db.transaction((txn) async {
      await _claimPending(txn, candidateId, ExtractionQueueStatus.rejected);
      await _auditInTransaction(txn, 'reject', candidateId);
    });
  }

  /// pending 후보를 조건부 update로 선점하고 row를 반환한다.
  Future<ExtractionCandidate> _claimPending(
    Transaction txn,
    String candidateId,
    ExtractionQueueStatus newStatus,
  ) async {
    final rows = await txn.query(
      'personal_extraction_queue',
      where: "id = ? AND status = ?",
      whereArgs: [candidateId, ExtractionQueueStatus.pending.name],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Candidate is not pending: $candidateId');
    }
    final candidate = _mapCandidate(rows.first);
    final now = DateTime.now().toUtc().toIso8601String();
    final claimed = await txn.update(
      'personal_extraction_queue',
      {
        'status': _statusToDb(newStatus),
        'updated_at': now,
      },
      where: "id = ? AND status = ?",
      whereArgs: [candidateId, ExtractionQueueStatus.pending.name],
    );
    if (claimed != 1) {
      throw StateError('Candidate already processed: $candidateId');
    }
    return candidate;
  }

  /// 트랜잭션 안에서 개인 아카이브 항목을 생성한다.
  Future<PersonalArchiveItem> _insertArchiveItem(
    Transaction txn, {
    required String itemType,
    required String title,
    required String content,
    String? sourceDocumentId,
    String? sourcePath,
    double? confidence,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await txn.insert('personal_archive_items', {
      'id': id,
      'item_type': itemType,
      'title': title,
      'content': content,
      'source_document_id': sourceDocumentId,
      'source_path': sourcePath,
      'confidence': confidence,
      'status': PersonalArchiveItemStatus.active.name,
      'created_at': now,
      'updated_at': now,
    });
    await txn.insert('audit_logs', {
      'id': _uuid.v4(),
      'actor': 'user',
      'action': 'create',
      'target_type': itemType,
      'target_id': id,
      'detail_json': '{}',
      'occurred_at': now,
    });
    return PersonalArchiveItem(
      id: id,
      itemType: itemType,
      title: title,
      content: content,
      sourceDocumentId: sourceDocumentId,
      sourcePath: sourcePath,
      confidence: confidence,
      status: PersonalArchiveItemStatus.active,
      createdAt: DateTime.parse(now).toLocal(),
      updatedAt: DateTime.parse(now).toLocal(),
    );
  }

  /// queue 상태를 DB 문자열로 변환한다.
  String _statusToDb(ExtractionQueueStatus status) {
    if (status == ExtractionQueueStatus.editedApproved) return 'edited_approved';
    return status.name;
  }

  /// DB status 문자열을 enum으로 변환한다.
  ExtractionQueueStatus _statusFromDb(String raw) {
    if (raw == 'edited_approved') return ExtractionQueueStatus.editedApproved;
    return ExtractionQueueStatus.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => ExtractionQueueStatus.pending,
    );
  }

  /// 감사 로그에 후보 ID만 기록한다.
  Future<void> _audit(String action, String candidateId) async {
    await _db.insert('audit_logs', {
      'id': _uuid.v4(),
      'actor': 'user',
      'action': action,
      'target_type': 'extraction_candidate',
      'target_id': candidateId,
      'detail_json': '{}',
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// 트랜잭션 안에서 감사 로그에 후보 ID만 기록한다.
  Future<void> _auditInTransaction(Transaction txn, String action, String candidateId) async {
    await txn.insert('audit_logs', {
      'id': _uuid.v4(),
      'actor': 'user',
      'action': action,
      'target_type': 'extraction_candidate',
      'target_id': candidateId,
      'detail_json': '{}',
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// DB row를 ExtractionCandidate로 변환한다.
  ExtractionCandidate _mapCandidate(Map<String, Object?> row) {
    return ExtractionCandidate(
      id: row['id'] as String,
      sourceDocumentId: row['source_document_id'] as String?,
      sourcePath: row['source_path'] as String?,
      candidateType: row['candidate_type'] as String,
      candidateTitle: row['candidate_title'] as String,
      candidateContent: row['candidate_content'] as String,
      confidence: (row['confidence'] as num?)?.toDouble(),
      reason: row['reason'] as String?,
      status: _statusFromDb(row['status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }
}
