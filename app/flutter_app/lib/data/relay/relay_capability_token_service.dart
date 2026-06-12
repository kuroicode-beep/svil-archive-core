// relay_capability_token_service.dart — relay result capability token (hash only)

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/database_service_impl.dart';
import '../db/sqlite_write_guard.dart';
import '../platform/platform_path_adapter.dart';

/// relay task용 capability token 발행·검증 (원문은 DB에 저장하지 않음).
class RelayCapabilityTokenService {
  final DatabaseServiceImpl _databaseService;
  final SqliteWriteGuard _writeGuard;
  final Uuid _uuid = const Uuid();

  RelayCapabilityTokenService({
    required DatabaseServiceImpl databaseService,
    SqliteWriteGuard? writeGuard,
  })  : _databaseService = databaseService,
        _writeGuard = writeGuard ?? SqliteWriteGuard();

  Database get _db => _databaseService.requireDatabase();

  /// 토큰 원문의 SHA-256 hash를 계산한다.
  static String hashToken(String plainToken) {
    return sha256.convert(utf8.encode(plainToken)).toString();
  }

  /// task에 capability token을 발행하고 원문을 1회 반환한다.
  Future<String> issueForTask({
    required String taskId,
    required String allowedAction,
    required String allowedTarget,
    String? targetDocumentId,
    String? targetPath,
    Duration validity = const Duration(hours: 24),
  }) async {
    return _writeGuard.run(() async {
      final plain = _uuid.v4();
      final now = DateTime.now().toUtc();
      final expires = now.add(validity);
      await _db.insert('relay_capability_tokens', {
        'id': _uuid.v4(),
        'task_id': taskId,
        'token_hash': hashToken(plain),
        'allowed_action': allowedAction,
        'allowed_target': allowedTarget,
        'target_document_id': targetDocumentId,
        'target_path': targetPath,
        'expires_at': expires.toIso8601String(),
        'status': 'active',
        'created_at': now.toIso8601String(),
      });
      return plain;
    });
  }

  /// 비어 있지 않은 문자열인지 확인한다.
  static bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;

  /// relay target path를 비교 가능한 형태로 정규화한다.
  static String _normalizeTargetPath(String path) {
    return normalizePlatformPath(path).replaceAll('\\', '/').toLowerCase();
  }

  /// 두 target path가 동일한지 정규화 후 비교한다.
  static bool _targetPathsMatch(String expected, String? actual) {
    if (!_hasValue(actual)) return false;
    return _normalizeTargetPath(expected) == _normalizeTargetPath(actual!);
  }

  /// result target이 allowed_target과 일치하는지 확인한다.
  static bool _matchesAllowedTarget({
    required String allowedTarget,
    String? targetDocumentId,
    String? targetPath,
  }) {
    if (_hasValue(targetDocumentId) &&
        targetDocumentId!.trim() == allowedTarget.trim()) {
      return true;
    }
    if (_hasValue(targetPath) && _targetPathsMatch(allowedTarget, targetPath)) {
      return true;
    }
    return false;
  }

  /// capability token을 검증한다.
  Future<bool> validate({
    required String taskId,
    required String plainToken,
    required String resultType,
    String? targetDocumentId,
    String? targetPath,
  }) async {
    final rows = await _db.query(
      'relay_capability_tokens',
      where: 'task_id = ? AND status = ?',
      whereArgs: [taskId, 'active'],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final row = rows.first;
    if (hashToken(plainToken) != (row['token_hash'] as String? ?? '')) {
      return false;
    }
    final expiresRaw = row['expires_at'] as String?;
    if (expiresRaw != null &&
        !DateTime.parse(expiresRaw).toUtc().isAfter(DateTime.now().toUtc())) {
      return false;
    }
    final allowedAction = row['allowed_action'] as String? ?? '';
    if (allowedAction.isNotEmpty && allowedAction != resultType) {
      return false;
    }

    final allowedTarget = (row['allowed_target'] as String? ?? '').trim();
    final expectedDoc = row['target_document_id'] as String?;
    final expectedPath = row['target_path'] as String?;

    // 저장된 document target이 있으면 result도 반드시 제공·일치해야 한다.
    if (_hasValue(expectedDoc)) {
      if (!_hasValue(targetDocumentId) ||
          expectedDoc!.trim() != targetDocumentId!.trim()) {
        return false;
      }
    }

    // 저장된 path target이 있으면 result도 반드시 제공·일치해야 한다.
    if (_hasValue(expectedPath)) {
      if (!_targetPathsMatch(expectedPath!, targetPath)) {
        return false;
      }
    }

    // allowed_target은 result의 document id 또는 path 중 하나와 일치해야 한다.
    if (allowedTarget.isNotEmpty) {
      if (!_matchesAllowedTarget(
        allowedTarget: allowedTarget,
        targetDocumentId: targetDocumentId,
        targetPath: targetPath,
      )) {
        return false;
      }
    }

    return true;
  }

  /// 사용된 토큰을 consumed로 표시한다.
  Future<void> markConsumed(String taskId) async {
    await _writeGuard.run(() async {
      await _db.update(
        'relay_capability_tokens',
        {'status': 'consumed'},
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
    });
  }
}
