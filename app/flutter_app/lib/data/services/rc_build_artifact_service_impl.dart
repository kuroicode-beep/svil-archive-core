// rc_build_artifact_service_impl.dart — RC build artifact SQLite 구현

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/rc_build_approval.dart';
import '../../domain/services/rc_build_artifact_service.dart';
import '../../domain/utils/path_masking.dart';
import '../db/database_service_impl.dart';

class RcBuildArtifactServiceImpl implements RcBuildArtifactService {
  final DatabaseServiceImpl _databaseService;
  final Uuid _uuid = const Uuid();

  RcBuildArtifactServiceImpl({required DatabaseServiceImpl databaseService})
      : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<RcBuildArtifact> recordBuildArtifact({
    required String platform,
    required RcBuildType buildType,
    required String artifactPath,
    required String commitHash,
    required RcBuildArtifactStatus status,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final masked = maskArtifactPath(artifactPath);
    final verifiedAt = status == RcBuildArtifactStatus.pass ? createdAt : null;
    await _db.insert('rc_build_artifacts', {
      'id': id,
      'platform': platform,
      'build_type': buildType.name,
      'artifact_path_masked': masked,
      'commit_hash': commitHash,
      'status': status.name,
      'created_at': createdAt,
      'verified_at': verifiedAt,
      'notes': notes,
    });
    return RcBuildArtifact(
      id: id,
      platform: platform,
      buildType: buildType,
      artifactPathMasked: masked,
      commitHash: commitHash,
      status: status,
      createdAt: DateTime.parse(createdAt).toLocal(),
      verifiedAt: verifiedAt != null ? DateTime.parse(verifiedAt).toLocal() : null,
      notes: notes,
    );
  }

  @override
  Future<List<RcBuildArtifact>> listBuildArtifacts({int limit = 50}) async {
    final rows = await _db.query(
      'rc_build_artifacts',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(_mapRow).toList();
  }

  /// DB row를 RcBuildArtifact로 변환한다.
  RcBuildArtifact _mapRow(Map<String, Object?> row) {
    return RcBuildArtifact(
      id: row['id'] as String,
      platform: row['platform'] as String,
      buildType: RcBuildType.values.firstWhere(
        (v) => v.name == (row['build_type'] as String? ?? 'rc'),
        orElse: () => RcBuildType.rc,
      ),
      artifactPathMasked: row['artifact_path_masked'] as String,
      commitHash: row['commit_hash'] as String,
      status: RcBuildArtifactStatus.values.firstWhere(
        (v) => v.name == (row['status'] as String? ?? 'pending'),
        orElse: () => RcBuildArtifactStatus.pending,
      ),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      verifiedAt: row['verified_at'] == null
          ? null
          : DateTime.parse(row['verified_at'] as String).toLocal(),
      notes: row['notes'] as String?,
    );
  }
}
