// document_import_service_impl.dart — 파일 Import dry-run / 정식 등록 구현

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../domain/models/document.dart';
import '../../domain/models/document_import.dart';
import '../../domain/services/document_file_store.dart';
import '../../domain/services/document_import_service.dart';
import '../../domain/services/document_repository.dart';
import '../sync/sync_service_impl.dart';
import '../../domain/services/workspace_file_inventory_service.dart';
import '../db/database_service_impl.dart';
import '../import/markdown_import_parser.dart';
import '../indexing/indexing_queue.dart';
import '../platform/path_adapter.dart';

class DocumentImportServiceImpl implements DocumentImportService {
  final DatabaseServiceImpl _databaseService;
  final DocumentRepository _repository;
  final DocumentFileStore _fileStore;
  final WorkspaceFileInventoryService _inventoryService;
  final SyncServiceImpl _syncService;
  final IndexingQueue _indexingQueue;
  final String _workspaceId;
  final String _workspaceRoot;

  DocumentImportServiceImpl({
    required DatabaseServiceImpl databaseService,
    required DocumentRepository repository,
    required DocumentFileStore fileStore,
    required WorkspaceFileInventoryService inventoryService,
    required SyncServiceImpl syncService,
    required IndexingQueue indexingQueue,
    required String workspaceId,
    required String workspaceRoot,
  })  : _databaseService = databaseService,
        _repository = repository,
        _fileStore = fileStore,
        _inventoryService = inventoryService,
        _syncService = syncService,
        _indexingQueue = indexingQueue,
        _workspaceId = workspaceId,
        _workspaceRoot = workspaceRoot;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<ImportDryRunResult> scanWorkspaceOrphans(DocumentImportOptions options) async {
    final paths = await _inventoryService.listWorkspaceMarkdownPaths();
    final absolute = paths
        .map((rel) => toAbsolutePath(_workspaceRoot, rel))
        .toList();
    return _scanAbsolutePaths(absolute, options);
  }

  @override
  Future<ImportDryRunResult> scanPaths(
    List<String> absolutePaths,
    DocumentImportOptions options,
  ) async {
    final expanded = await _expandAbsolutePaths(absolutePaths, options.includeSubfolders);
    return _scanAbsolutePaths(expanded, options);
  }

  @override
  Future<ImportDryRunResult> dryRun(DocumentImportOptions options) async {
    if (options.absolutePaths.isEmpty) {
      return scanWorkspaceOrphans(options);
    }
    return scanPaths(options.absolutePaths, options);
  }

  @override
  Future<ImportExecutionResult> executeImport(DocumentImportOptions options) async {
    if (options.dryRunOnly) {
      final preview = await dryRun(options);
      return ImportExecutionResult(
        dryRun: true,
        registeredCount: 0,
        failedCount: 0,
        skippedCount: preview.skipCount + preview.conflictCount + preview.duplicateCount + preview.invalidCount,
        preview: preview,
      );
    }

    final preview = await dryRun(options.copyWith(dryRunOnly: true));
    final importable = preview.candidates.where((c) => c.isImportable).toList();
    if (importable.isEmpty) {
      return ImportExecutionResult(
        dryRun: false,
        registeredCount: 0,
        failedCount: 0,
        skippedCount: preview.candidates.length,
        preview: preview,
      );
    }

    final backupPath = await _backupDatabase();
    final registeredIds = <String>[];
    final failures = <String>[];

    for (final candidate in importable) {
      try {
        final id = await _registerCandidate(candidate, options);
        registeredIds.add(id);
      } catch (e) {
        failures.add('${candidate.relativePath}: $e');
      }
    }

    for (final id in registeredIds) {
      await _indexingQueue.reindexDocument(id);
    }

    final reportPath = await _writeImportReport(
      preview: preview,
      registeredIds: registeredIds,
      failures: failures,
      backupPath: backupPath,
    );

    return ImportExecutionResult(
      dryRun: false,
      registeredCount: registeredIds.length,
      failedCount: failures.length,
      skippedCount: preview.candidates.length - importable.length,
      backupPath: backupPath,
      reportPath: reportPath,
      registeredDocumentIds: registeredIds,
      failures: failures,
      preview: preview,
    );
  }

  /// 절대경로 목록을 재귀 확장한다.
  Future<List<String>> _expandAbsolutePaths(
    List<String> absolutePaths,
    bool includeSubfolders,
  ) async {
    final results = <String>{};
    for (final raw in absolutePaths) {
      final path = p.normalize(raw);
      final entityType = await FileSystemEntity.type(path);
      if (entityType == FileSystemEntityType.directory) {
        await for (final entity in Directory(path).list(recursive: includeSubfolders)) {
          if (entity is File && p.extension(entity.path).toLowerCase() == '.md') {
            results.add(p.normalize(entity.path));
          }
        }
      } else if (entityType == FileSystemEntityType.file &&
          p.extension(path).toLowerCase() == '.md') {
        results.add(path);
      }
    }
    return results.toList()..sort();
  }

  /// 절대경로 후보를 스캔한다.
  Future<ImportDryRunResult> _scanAbsolutePaths(
    List<String> absolutePaths,
    DocumentImportOptions options,
  ) async {
    final dbRows = await _db.query(
      'documents',
      where: 'workspace_id = ?',
      whereArgs: [_workspaceId],
    );
    final byPath = <String, Map<String, Object?>>{};
    final bySacId = <String, Map<String, Object?>>{};
    final byHash = <String, List<Map<String, Object?>>>{};
    for (final row in dbRows) {
      final rel = row['relative_path'] as String;
      byPath[rel] = row;
      final sacFromMeta = row['id'] as String;
      bySacId[sacFromMeta] = row;
      final hash = row['content_hash'] as String? ?? '';
      byHash.putIfAbsent(hash, () => []).add(row);
    }

    final candidates = <ImportCandidate>[];
    for (final absolute in absolutePaths) {
      candidates.add(
        await _buildCandidate(
          absolute,
          options,
          byPath: byPath,
          bySacId: bySacId,
          byHash: byHash,
        ),
      );
    }

    return _summarize(candidates);
  }

  /// 단일 파일 후보를 구성한다.
  Future<ImportCandidate> _buildCandidate(
    String absolutePath,
    DocumentImportOptions options, {
    required Map<String, Map<String, Object?>> byPath,
    required Map<String, Map<String, Object?>> bySacId,
    required Map<String, List<Map<String, Object?>>> byHash,
  }) async {
    if (!await File(absolutePath).exists()) {
      return ImportCandidate(
        relativePath: absolutePath,
        title: p.basename(absolutePath),
        categoryPath: '',
        contentHash: '',
        status: ImportCandidateStatus.invalid,
        sourceAbsolutePath: absolutePath,
        message: 'File not found',
      );
    }

    String relativePath;
    ImportCandidateStatus status = ImportCandidateStatus.ready;
    String? sourceAbsolutePath;

    if (isPathInsideWorkspaceRoot(_workspaceRoot, absolutePath)) {
      relativePath = toRelativePath(_workspaceRoot, absolutePath);
    } else {
      final fileName = sanitizeDocumentFileName(p.basename(absolutePath));
      relativePath = p.posix.join('documents', 'Import', fileName);
      status = ImportCandidateStatus.copyRequired;
      sourceAbsolutePath = absolutePath;
    }

    if (!relativePath.startsWith('documents/') || !relativePath.toLowerCase().endsWith('.md')) {
      return ImportCandidate(
        relativePath: relativePath,
        title: p.basename(relativePath),
        categoryPath: '',
        contentHash: '',
        status: ImportCandidateStatus.invalid,
        sourceAbsolutePath: sourceAbsolutePath ?? absolutePath,
        message: 'Only documents/*.md paths are supported',
      );
    }

    if (options.skipRegistered && byPath.containsKey(relativePath)) {
      return ImportCandidate(
        relativePath: relativePath,
        title: titleFromRelativePath(relativePath),
        categoryPath: categoryPathFromRelativePath(relativePath),
        contentHash: byPath[relativePath]!['content_hash'] as String? ?? '',
        status: ImportCandidateStatus.skipRegistered,
        sourceAbsolutePath: sourceAbsolutePath ?? absolutePath,
        message: 'Already registered',
      );
    }

    final raw = await File(absolutePath).readAsString();
    final parsed = parseMarkdownForImport(raw);
    final title = parsed.title?.trim().isNotEmpty == true
        ? parsed.title!.trim()
        : titleFromRelativePath(relativePath);
    final categoryPath = categoryPathFromRelativePath(relativePath);
    final sacId = parsed.sacId?.trim().isNotEmpty == true
        ? parsed.sacId!.trim()
        : (options.generateSacId ? generateImportSacId(parsed.contentHash) : null);

    if (sacId != null && bySacId.containsKey(sacId)) {
      final existingPath = bySacId[sacId]!['relative_path'] as String?;
      if (existingPath != relativePath) {
        return ImportCandidate(
          relativePath: relativePath,
          title: title,
          categoryPath: categoryPath,
          existingSacId: parsed.sacId,
          proposedSacId: sacId,
          contentHash: parsed.contentHash,
          status: ImportCandidateStatus.conflictSacId,
          sourceAbsolutePath: sourceAbsolutePath ?? absolutePath,
          message: 'sac_id already used by $existingPath',
        );
      }
    }

    final hashMatches = byHash[parsed.contentHash] ?? const [];
    if (hashMatches.isNotEmpty &&
        !hashMatches.any((row) => row['relative_path'] == relativePath)) {
      return ImportCandidate(
        relativePath: relativePath,
        title: title,
        categoryPath: categoryPath,
        existingSacId: parsed.sacId,
        proposedSacId: sacId,
        contentHash: parsed.contentHash,
        status: ImportCandidateStatus.duplicateHash,
        sourceAbsolutePath: sourceAbsolutePath ?? absolutePath,
        message: 'Duplicate content hash candidate',
      );
    }

    return ImportCandidate(
      relativePath: relativePath,
      title: title,
      categoryPath: categoryPath,
      existingSacId: parsed.sacId,
      proposedSacId: sacId,
      contentHash: parsed.contentHash,
      status: status,
      sourceAbsolutePath: sourceAbsolutePath ?? absolutePath,
    );
  }

  /// 후보 목록을 요약한다.
  ImportDryRunResult _summarize(List<ImportCandidate> candidates) {
    var ready = 0;
    var skip = 0;
    var conflict = 0;
    var duplicate = 0;
    var invalid = 0;
    for (final c in candidates) {
      switch (c.status) {
        case ImportCandidateStatus.ready:
        case ImportCandidateStatus.copyRequired:
          ready++;
        case ImportCandidateStatus.skipRegistered:
          skip++;
        case ImportCandidateStatus.conflictSacId:
          conflict++;
        case ImportCandidateStatus.duplicateHash:
          duplicate++;
        case ImportCandidateStatus.invalid:
          invalid++;
      }
    }
    return ImportDryRunResult(
      candidates: candidates,
      readyCount: ready,
      skipCount: skip,
      conflictCount: conflict,
      duplicateCount: duplicate,
      invalidCount: invalid,
    );
  }

  /// 단일 후보를 DB에 등록한다.
  Future<String> _registerCandidate(
    ImportCandidate candidate,
    DocumentImportOptions options,
  ) async {
    final sacId = candidate.proposedSacId ??
        candidate.existingSacId ??
        generateImportSacId(candidate.contentHash);

    if (candidate.status == ImportCandidateStatus.copyRequired) {
      final src = candidate.sourceAbsolutePath;
      if (src == null) {
        throw StateError('Missing source path for copy');
      }
      final targetAbs = toAbsolutePath(_workspaceRoot, candidate.relativePath);
      await Directory(p.dirname(targetAbs)).create(recursive: true);
      await File(src).copy(targetAbs);
    }

    final raw = await _fileStore.readContent(candidate.relativePath);
    final parsed = parseMarkdownForImport(raw);

    if (options.writeFrontmatter && parsed.sacId == null) {
      final merged = buildImportFrontmatterMarkdown(
        sacId: sacId,
        workspaceId: _workspaceId,
        body: parsed.body,
        title: candidate.title,
        author: parsed.author,
        project: parsed.project,
        category: candidate.categoryPath,
      );
      await _fileStore.writeContent(candidate.relativePath, merged);
    }

    final now = DateTime.now();
    final metadata = DocumentMetadata(
      id: sacId,
      path: candidate.relativePath,
      title: candidate.title,
      author: parsed.author,
      project: parsed.project,
      type: candidate.categoryPath.isEmpty ? null : candidate.categoryPath,
      status: DocumentStatus.active,
      createdAt: now,
      updatedAt: now,
      tags: parsed.tags,
      contentHash: parsed.contentHash,
      revision: 1,
      sacSchema: '1',
    );

    await _repository.save(metadata);
    await _syncService.createInitialState(
      documentId: sacId,
      actor: 'import',
      revision: 1,
    );
    return sacId;
  }

  /// import 전 SQLite 백업을 생성한다.
  Future<String> _backupDatabase() async {
    final src = databaseFilePath(_workspaceRoot);
    final backupDir = importBackupDirectoryPath(_workspaceRoot);
    await Directory(backupDir).create(recursive: true);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final dest = p.join(backupDir, 'sac_pre_import_$stamp.sqlite');
    await File(src).copy(dest);
    return dest;
  }

  /// import report Markdown을 저장한다.
  Future<String> _writeImportReport({
    required ImportDryRunResult preview,
    required List<String> registeredIds,
    required List<String> failures,
    required String backupPath,
  }) async {
    final reportDir = importReportDirectoryPath(_workspaceRoot);
    await Directory(reportDir).create(recursive: true);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final reportPath = p.join(reportDir, 'import_report_$stamp.md');
    final buffer = StringBuffer()
      ..writeln('# SAC Import Report')
      ..writeln()
      ..writeln('- registered: ${registeredIds.length}')
      ..writeln('- failed: ${failures.length}')
      ..writeln('- dry-run ready: ${preview.readyCount}')
      ..writeln('- skipped: ${preview.skipCount}')
      ..writeln('- conflicts: ${preview.conflictCount}')
      ..writeln('- duplicates: ${preview.duplicateCount}')
      ..writeln('- backup: `[backup]`')
      ..writeln()
      ..writeln('## Registered document ids')
      ..writeln();
    for (final id in registeredIds) {
      buffer.writeln('- $id');
    }
    if (failures.isNotEmpty) {
      buffer.writeln('\n## Failures\n');
      for (final failure in failures) {
        buffer.writeln('- $failure');
      }
    }
    var content = buffer.toString().replaceAll('[backup]', p.basename(backupPath));
    await File(reportPath).writeAsString(content, encoding: utf8);
    return reportPath;
  }
}
