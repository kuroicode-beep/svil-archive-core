// workspace_registry.dart — 앱 전역 Workspace 목록 영속성

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/workspace.dart';

class WorkspaceRegistry {
  final String? _overrideDirectory;
  List<Workspace> _cache = [];

  WorkspaceRegistry({String? overrideDirectory})
      : _overrideDirectory = overrideDirectory;

  /// 저장된 Workspace 목록을 로드한다.
  Future<List<Workspace>> load() async {
    final file = await _registryFile();
    if (!await file.exists()) {
      _cache = [];
      return _cache;
    }
    try {
      final raw = await file.readAsString(encoding: utf8);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _cache = [];
        return _cache;
      }
      _cache = decoded
          .whereType<Map>()
          .map((item) => Workspace(
                id: item['id'] as String,
                name: item['name'] as String,
                rootPath: item['root_path'] as String,
                createdAt: DateTime.parse(item['created_at'] as String).toLocal(),
                lastOpenedAt:
                    DateTime.parse(item['last_opened_at'] as String).toLocal(),
              ))
          .toList();
      return _cache;
    } catch (_) {
      _cache = [];
      return _cache;
    }
  }

  /// Workspace를 레지스트리에 저장한다.
  Future<void> upsert(Workspace workspace) async {
    await load();
    final index = _cache.indexWhere((w) => w.id == workspace.id);
    if (index >= 0) {
      _cache[index] = workspace;
    } else {
      _cache.add(workspace);
    }
    await _persist();
  }

  /// Workspace를 레지스트리에서 제거한다.
  Future<void> remove(String workspaceId) async {
    await load();
    _cache.removeWhere((w) => w.id == workspaceId);
    await _persist();
  }

  /// 레지스트리 파일 경로를 반환한다.
  Future<File> _registryFile() async {
    final basePath = _overrideDirectory ??
        (await getApplicationSupportDirectory()).path;
    final dir = Directory(p.join(basePath, 'SAC'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'workspaces_registry.json'));
  }

  /// 메모리 캐시를 파일에 저장한다.
  Future<void> _persist() async {
    final file = await _registryFile();
    final data = _cache
        .map((w) => {
              'id': w.id,
              'name': w.name,
              'root_path': w.rootPath,
              'created_at': w.createdAt.toUtc().toIso8601String(),
              'last_opened_at': w.lastOpenedAt.toUtc().toIso8601String(),
            })
        .toList();
    await file.writeAsString(jsonEncode(data), encoding: utf8, flush: true);
  }
}
