// document_file_store_impl.dart — Markdown 파일 I/O 구현

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/document.dart';
import '../../domain/services/document_file_store.dart';
import '../platform/path_adapter.dart';
import 'content_hasher.dart';
import 'frontmatter_parser.dart';

class DocumentFileStoreImpl implements DocumentFileStore {
  final String workspaceRoot;

  DocumentFileStoreImpl({required this.workspaceRoot});

  @override
  Future<String> readContent(String relativePath) async {
    final file = File(toAbsolutePath(workspaceRoot, relativePath));
    if (!await file.exists()) {
      throw FileSystemException('Markdown file not found', file.path);
    }
    return file.readAsString(encoding: utf8);
  }

  @override
  Future<void> writeContent(String relativePath, String markdownWithFrontmatter) async {
    final file = File(toAbsolutePath(workspaceRoot, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(markdownWithFrontmatter, encoding: utf8, flush: true);
  }

  @override
  Future<bool> exists(String relativePath) async {
    return File(toAbsolutePath(workspaceRoot, relativePath)).exists();
  }

  @override
  Future<void> move(String fromPath, String toPath) async {
    final from = File(toAbsolutePath(workspaceRoot, fromPath));
    final to = File(toAbsolutePath(workspaceRoot, toPath));
    await to.parent.create(recursive: true);
    await from.rename(to.path);
  }

  @override
  Future<void> delete(String relativePath) async {
    final file = File(toAbsolutePath(workspaceRoot, relativePath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<String> computeHash(String relativePath) async {
    final raw = await readContent(relativePath);
    try {
      final parsed = parseMarkdownWithFrontmatter(raw);
      return computeContentHash(parsed.body);
    } catch (_) {
      return computeContentHash(raw);
    }
  }

  @override
  Future<List<String>> listMarkdownFiles(String relativeDirPath) async {
    final dir = Directory(toAbsolutePath(workspaceRoot, relativeDirPath));
    if (!await dir.exists()) return [];

    final results = <String>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && p.extension(entity.path).toLowerCase() == '.md') {
        results.add(toRelativePath(workspaceRoot, entity.path));
      }
    }
    results.sort();
    return results;
  }

  @override
  Future<DocumentMetadata> parseFrontmatter(String relativePath) async {
    final raw = await readContent(relativePath);
    final parsed = parseMarkdownWithFrontmatter(raw);
    final title = _titleFromPath(relativePath);
    return toMetadataDraft(
      frontmatter: parsed,
      relativePath: relativePath,
      title: title,
      category: _categoryFromPath(relativePath),
    );
  }

  /// 상대경로에서 문서 제목을 추출한다.
  String _titleFromPath(String relativePath) {
    final base = p.basenameWithoutExtension(relativePath);
    return base.isEmpty ? 'Untitled' : base;
  }

  /// 상대경로에서 카테고리 폴더명을 추출한다.
  String? _categoryFromPath(String relativePath) {
    final parts = p.posix.split(relativePath);
    if (parts.length >= 3 && parts[0] == 'documents') {
      return parts[1];
    }
    return null;
  }
}
