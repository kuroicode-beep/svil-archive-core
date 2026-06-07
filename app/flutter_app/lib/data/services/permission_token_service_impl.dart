// permission_token_service_impl.dart — 권한 토큰 SQLite 구현

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/work_queue.dart';
import '../../domain/services/permission_token_service.dart';
import '../db/database_service_impl.dart';

class PermissionTokenServiceImpl implements PermissionTokenService {
  final DatabaseServiceImpl _databaseService;
  final Uuid _uuid = const Uuid();

  PermissionTokenServiceImpl({required DatabaseServiceImpl databaseService})
      : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<PermissionTokenRecord> issueToken({
    required PermissionLevel tokenType,
    required String actor,
    required String scope,
    Duration? validity,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final expires = validity != null ? now.add(validity) : null;
    await _db.insert('permission_tokens', {
      'id': id,
      'token_type': tokenType.name,
      'actor': actor,
      'scope': scope,
      'status': 'active',
      'expires_at': expires?.toIso8601String(),
      'created_at': now.toIso8601String(),
    });
    await _audit('issue_token', id, tokenType.name);
    return PermissionTokenRecord(
      id: id,
      tokenType: tokenType,
      actor: actor,
      scope: scope,
      status: 'active',
      expiresAt: expires?.toLocal(),
      createdAt: now.toLocal(),
    );
  }

  @override
  Future<void> revokeToken(String tokenId) async {
    await _db.update(
      'permission_tokens',
      {'status': 'revoked'},
      where: 'id = ?',
      whereArgs: [tokenId],
    );
    await _audit('revoke_token', tokenId, 'permission_token');
  }

  @override
  Future<List<PermissionTokenRecord>> listActiveTokens() async {
    final rows = await _db.query(
      'permission_tokens',
      where: "status = 'active'",
      orderBy: 'created_at DESC',
    );
    return rows.map(_mapRow).toList();
  }

  @override
  Future<int> countActiveByType(PermissionLevel type) async {
    final rows = await _db.query(
      'permission_tokens',
      where: "status = 'active' AND token_type = ?",
      whereArgs: [type.name],
    );
    return rows.where(_isNotExpired).length;
  }

  @override
  Future<bool> validateActiveToken({
    required String tokenId,
    required PermissionLevel tokenType,
    required String actor,
    String? scope,
  }) async {
    final rows = await _db.query(
      'permission_tokens',
      where: 'id = ?',
      whereArgs: [tokenId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final row = rows.first;
    if ((row['status'] as String? ?? '') != 'active') return false;
    if ((row['token_type'] as String? ?? '') != tokenType.name) return false;
    if ((row['actor'] as String? ?? '') != actor) return false;
    if (scope != null && (row['scope'] as String? ?? '') != scope) return false;
    return _isNotExpired(row);
  }

  /// 토큰이 만료되지 않았는지 확인한다.
  bool _isNotExpired(Map<String, Object?> row) {
    final expiresRaw = row['expires_at'] as String?;
    if (expiresRaw == null) return true;
    return DateTime.parse(expiresRaw).toUtc().isAfter(DateTime.now().toUtc());
  }

  /// 감사 로그에 토큰 ID만 기록한다.
  Future<void> _audit(String action, String targetId, String targetType) async {
    await _db.insert('audit_logs', {
      'id': _uuid.v4(),
      'actor': 'user',
      'action': action,
      'target_type': targetType,
      'target_id': targetId,
      'detail_json': '{}',
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// DB row를 PermissionTokenRecord로 변환한다.
  PermissionTokenRecord _mapRow(Map<String, Object?> row) {
    return PermissionTokenRecord(
      id: row['id'] as String,
      tokenType: PermissionLevel.values.firstWhere(
        (p) => p.name == (row['token_type'] as String? ?? 'read'),
        orElse: () => PermissionLevel.read,
      ),
      actor: row['actor'] as String,
      scope: row['scope'] as String,
      status: row['status'] as String? ?? 'active',
      expiresAt: row['expires_at'] != null
          ? DateTime.parse(row['expires_at'] as String).toLocal()
          : null,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}
