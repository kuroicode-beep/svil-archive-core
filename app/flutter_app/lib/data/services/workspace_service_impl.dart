// workspace_service_impl.dart — Workspace 생성/열기 구현

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/workspace.dart';
import '../../domain/services/workspace_service.dart';
import '../db/database_service_impl.dart';
import '../platform/path_adapter.dart';
import 'workspace_registry.dart';

class WorkspaceServiceImpl implements WorkspaceService {
  final DatabaseServiceImpl _databaseService;
  final WorkspaceRegistry _registry;
  final Uuid _uuid = const Uuid();
  Workspace? _activeWorkspace;

  static const List<String> _defaultCategories = [
    'Dev',
    'Log',
    'Idea',
    'Research',
    'Blog',
    'Novel',
    'YT',
    'Resource',
    'IB',
  ];

  WorkspaceServiceImpl({
    required DatabaseServiceImpl databaseService,
    WorkspaceRegistry? registry,
  })  : _databaseService = databaseService,
        _registry = registry ?? WorkspaceRegistry();

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<List<Workspace>> listWorkspaces() => _registry.load();

  @override
  Future<Workspace> createWorkspace({
    required String name,
    required String rootPath,
  }) async {
    final normalizedRoot = p.normalize(rootPath);
    final workspace = Workspace(
      id: _uuid.v4(),
      name: name,
      rootPath: normalizedRoot,
      createdAt: DateTime.now(),
      lastOpenedAt: DateTime.now(),
    );

    await _createFolderStructure(normalizedRoot);
    await _writeSettingsJson(workspace);
    await _databaseService.initialize(databaseFilePath(normalizedRoot));

    await _db.insert('workspaces', _workspaceToRow(workspace));
    await _saveActiveWorkspaceSetting(workspace.id);

    await _registry.upsert(workspace);
    _activeWorkspace = workspace;
    return workspace;
  }

  @override
  Future<Workspace> openWorkspace(String workspaceId) async {
    final workspaces = await _registry.load();
    final workspace = workspaces.firstWhere(
      (w) => w.id == workspaceId,
      orElse: () => throw StateError('Workspace not found: $workspaceId'),
    );
    return _openWorkspaceRecord(workspace);
  }

  /// 기존 Workspace 폴더 경로로 열기를 수행한다.
  Future<Workspace> openWorkspaceAtPath(String rootPath) async {
    final normalizedRoot = p.normalize(rootPath);
    await _validateWorkspace(normalizedRoot);
    await _databaseService.initialize(databaseFilePath(normalizedRoot));

    final workspaces = await _registry.load();
    final existing = workspaces.where((w) => w.rootPath == normalizedRoot);
    if (existing.isNotEmpty) {
      return _openWorkspaceRecord(existing.first);
    }

    final name = p.basename(normalizedRoot);
    return createWorkspace(name: name, rootPath: normalizedRoot);
  }

  @override
  Future<Workspace?> getActiveWorkspace() async => _activeWorkspace;

  @override
  Future<void> removeWorkspace(String workspaceId) async {
    await _registry.remove(workspaceId);
    if (_activeWorkspace?.id == workspaceId) {
      _activeWorkspace = null;
    }
  }

  /// Workspace 레코드를 열고 lastOpenedAt을 갱신한다.
  Future<Workspace> _openWorkspaceRecord(Workspace workspace) async {
    await _validateWorkspace(workspace.rootPath);
    await _databaseService.initialize(databaseFilePath(workspace.rootPath));

    final updated = workspace.copyWith(lastOpenedAt: DateTime.now());
    await _db.insert(
      'workspaces',
      _workspaceToRow(updated),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _saveActiveWorkspaceSetting(updated.id);
    await _registry.upsert(updated);
    _activeWorkspace = updated;
    return updated;
  }

  /// active workspace 설정을 app_settings에 저장한다.
  Future<void> _saveActiveWorkspaceSetting(String workspaceId) async {
    await _db.insert('app_settings', {
      'key': 'active_workspace_id',
      'value': workspaceId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Workspace 기본 폴더 구조를 생성한다.
  Future<void> _createFolderStructure(String rootPath) async {
    final root = Directory(rootPath);
    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    for (final category in _defaultCategories) {
      await Directory(p.join(rootPath, 'documents', category))
          .create(recursive: true);
    }

    for (final sub in ['trash', 'backups', 'logs', 'queue', 'mcp', 'sync_journal']) {
      await Directory(p.join(sacDirectoryPath(rootPath), sub))
          .create(recursive: true);
    }
  }

  /// Workspace 유효성을 검사한다.
  Future<void> _validateWorkspace(String rootPath) async {
    final root = Directory(rootPath);
    if (!await root.exists()) {
      throw StateError('Workspace path does not exist: $rootPath');
    }
    final sacDir = Directory(sacDirectoryPath(rootPath));
    if (!await sacDir.exists()) {
      await _createFolderStructure(rootPath);
    }
  }

  /// settings.json에 Workspace 메타데이터를 기록한다.
  Future<void> _writeSettingsJson(Workspace workspace) async {
    final file = File(settingsJsonPath(workspace.rootPath));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'workspace_id': workspace.id,
        'workspace_name': workspace.name,
        'created_at': workspace.createdAt.toUtc().toIso8601String(),
      }),
      encoding: utf8,
      flush: true,
    );
  }

  /// Workspace를 DB row로 변환한다.
  Map<String, Object?> _workspaceToRow(Workspace workspace) {
    return {
      'id': workspace.id,
      'name': workspace.name,
      'root_path': workspace.rootPath,
      'created_at': workspace.createdAt.toUtc().toIso8601String(),
      'last_opened_at': workspace.lastOpenedAt.toUtc().toIso8601String(),
    };
  }
}
