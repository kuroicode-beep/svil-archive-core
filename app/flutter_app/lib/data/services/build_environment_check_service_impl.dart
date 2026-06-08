// build_environment_check_service_impl.dart — 빌드/실행 환경 점검 SQLite 구현

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/build_environment_check.dart';
import '../../domain/services/build_environment_check_service.dart';
import '../db/database_service_impl.dart';
import '../db/migrations.dart';
import '../platform/path_adapter.dart';

class BuildEnvironmentCheckServiceImpl implements BuildEnvironmentCheckService {
  final DatabaseServiceImpl _databaseService;
  final String? workspaceRoot;
  final String? mcpSidecarDistPath;
  final Uuid _uuid = const Uuid();

  BuildEnvironmentCheckServiceImpl({
    required DatabaseServiceImpl databaseService,
    this.workspaceRoot,
    this.mcpSidecarDistPath,
  }) : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<List<BuildEnvironmentCheck>> runChecks() async {
    final now = DateTime.now().toUtc();
    final checks = <BuildEnvironmentCheck>[
      await _checkSchemaVersion(now),
      await _checkDatabaseAccessible(now),
      await _checkWorkspaceWritable(now),
      await _checkMcpSidecar(now),
      await _checkPlatform(now),
    ];
    await _persistChecks(checks);
    return checks;
  }

  @override
  Future<List<BuildEnvironmentCheck>> getLatestChecks() async {
    final rows = await _db.query(
      'build_environment_checks',
      orderBy: 'checked_at DESC',
      limit: 20,
    );
    if (rows.isEmpty) return [];
    final latestStamp = rows.first['checked_at'] as String;
    return rows
        .where((row) => row['checked_at'] == latestStamp)
        .map(_mapRow)
        .toList();
  }

  /// SQLite 스키마 버전을 점검한다.
  Future<BuildEnvironmentCheck> _checkSchemaVersion(DateTime now) async {
    final version = await _databaseService.getSchemaVersion();
    if (version == kSacSchemaVersion) {
      return _buildCheck(
        checkName: 'schema_version',
        status: BuildCheckStatus.pass,
        message: 'schema v$version',
        checkedAt: now,
      );
    }
    return _buildCheck(
      checkName: 'schema_version',
      status: BuildCheckStatus.fail,
      message: 'expected v$kSacSchemaVersion, actual v$version',
      checkedAt: now,
    );
  }

  /// DB 접근 가능 여부를 점검한다.
  Future<BuildEnvironmentCheck> _checkDatabaseAccessible(DateTime now) async {
    try {
      await _db.rawQuery('SELECT 1');
      return _buildCheck(
        checkName: 'database_access',
        status: BuildCheckStatus.pass,
        message: 'SQLite accessible',
        checkedAt: now,
      );
    } catch (e) {
      return _buildCheck(
        checkName: 'database_access',
        status: BuildCheckStatus.fail,
        message: 'SQLite error: $e',
        checkedAt: now,
      );
    }
  }

  /// workspace 쓰기 가능 여부를 점검한다.
  Future<BuildEnvironmentCheck> _checkWorkspaceWritable(DateTime now) async {
    final root = workspaceRoot;
    if (root == null || root.isEmpty) {
      return _buildCheck(
        checkName: 'workspace_writable',
        status: BuildCheckStatus.warn,
        message: 'workspace not opened',
        checkedAt: now,
      );
    }
    try {
      final sacDir = Directory(resolveWorkspacePath(root, '.sac'));
      if (!await sacDir.exists()) {
        await sacDir.create(recursive: true);
      }
      final probe = File(p.join(sacDir.path, '.write_probe'));
      await probe.writeAsString('ok');
      await probe.delete();
      return _buildCheck(
        checkName: 'workspace_writable',
        status: BuildCheckStatus.pass,
        message: '.sac writable',
        checkedAt: now,
      );
    } catch (e) {
      return _buildCheck(
        checkName: 'workspace_writable',
        status: BuildCheckStatus.fail,
        message: 'write probe failed: $e',
        checkedAt: now,
      );
    }
  }

  /// MCP sidecar 빌드 존재 여부를 점검한다.
  Future<BuildEnvironmentCheck> _checkMcpSidecar(DateTime now) async {
    final dist = mcpSidecarDistPath ?? resolveMcpSidecarDistPath();
    if (dist == null) {
      return _buildCheck(
        checkName: 'mcp_sidecar',
        status: BuildCheckStatus.warn,
        message: 'sidecar path not resolved',
        checkedAt: now,
      );
    }
    final indexJs = File(p.join(dist, 'index.js'));
    if (await indexJs.exists()) {
      return _buildCheck(
        checkName: 'mcp_sidecar',
        status: BuildCheckStatus.pass,
        message: 'dist/index.js present',
        checkedAt: now,
      );
    }
    return _buildCheck(
      checkName: 'mcp_sidecar',
      status: BuildCheckStatus.warn,
      message: 'dist/index.js missing — run sidecar build',
      checkedAt: now,
    );
  }

  /// 현재 플랫폼을 점검한다.
  Future<BuildEnvironmentCheck> _checkPlatform(DateTime now) async {
    final os = Platform.operatingSystem;
    final supported = os == 'windows' || os == 'macos' || os == 'linux';
    return _buildCheck(
      checkName: 'platform',
      status: supported ? BuildCheckStatus.pass : BuildCheckStatus.warn,
      message: 'running on $os',
      checkedAt: now,
    );
  }

  /// 점검 결과를 DB에 저장한다.
  Future<void> _persistChecks(List<BuildEnvironmentCheck> checks) async {
    final batch = _db.batch();
    for (final check in checks) {
      batch.insert('build_environment_checks', {
        'id': check.id,
        'check_name': check.checkName,
        'status': check.status.name,
        'message': check.message,
        'checked_at': check.checkedAt.toUtc().toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
  }

  /// BuildEnvironmentCheck 인스턴스를 생성한다.
  BuildEnvironmentCheck _buildCheck({
    required String checkName,
    required BuildCheckStatus status,
    required String message,
    required DateTime checkedAt,
  }) {
    return BuildEnvironmentCheck(
      id: _uuid.v4(),
      checkName: checkName,
      status: status,
      message: message,
      checkedAt: checkedAt.toLocal(),
    );
  }

  /// DB row를 BuildEnvironmentCheck로 변환한다.
  BuildEnvironmentCheck _mapRow(Map<String, Object?> row) {
    return BuildEnvironmentCheck(
      id: row['id'] as String,
      checkName: row['check_name'] as String,
      status: BuildCheckStatus.values.firstWhere(
        (s) => s.name == (row['status'] as String? ?? 'warn'),
        orElse: () => BuildCheckStatus.warn,
      ),
      message: row['message'] as String? ?? '',
      checkedAt: DateTime.parse(row['checked_at'] as String).toLocal(),
    );
  }
}

/// 개발 환경에서 MCP sidecar dist 경로를 자동 탐지한다.
String? resolveMcpSidecarDistPath() {
  final candidates = <String>[
    p.normalize(p.join(Directory.current.path, '..', '..', 'mcp', 'sidecar', 'dist')),
    p.normalize(p.join(Directory.current.path, '..', 'mcp', 'sidecar', 'dist')),
    p.normalize(p.join(Directory.current.path, 'mcp', 'sidecar', 'dist')),
  ];
  for (final candidate in candidates) {
    if (File(p.join(candidate, 'index.js')).existsSync()) {
      return candidate;
    }
  }
  for (final candidate in candidates) {
    if (Directory(candidate).existsSync()) {
      return candidate;
    }
  }
  return candidates.isEmpty ? null : candidates.first;
}
