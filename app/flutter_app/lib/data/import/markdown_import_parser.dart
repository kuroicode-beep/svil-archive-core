// markdown_import_parser.dart — Import용 느슨한 Markdown frontmatter 파싱

import 'package:path/path.dart' as p;

import '../file/content_hasher.dart';

class ImportMarkdownData {
  final String body;
  final String? sacId;
  final String? title;
  final String? author;
  final String? project;
  final String? category;
  final List<String> tags;
  final String contentHash;

  const ImportMarkdownData({
    required this.body,
    this.sacId,
    this.title,
    this.author,
    this.project,
    this.category,
    this.tags = const [],
    required this.contentHash,
  });
}

/// Import용 Markdown을 파싱한다 (sac_id 없어도 허용).
ImportMarkdownData parseMarkdownForImport(String raw) {
  final trimmed = raw.replaceFirst('\uFEFF', '');
  if (!trimmed.startsWith('---')) {
    final body = trimmed;
    return ImportMarkdownData(
      body: body,
      contentHash: computeContentHash(body),
    );
  }

  final endIndex = trimmed.indexOf('\n---', 3);
  if (endIndex < 0) {
    final body = trimmed;
    return ImportMarkdownData(
      body: body,
      contentHash: computeContentHash(body),
    );
  }

  final yamlBlock = trimmed.substring(3, endIndex).trim();
  final body = trimmed.substring(endIndex + 4).replaceFirst(RegExp(r'^\n'), '');
  final values = <String, String>{};
  for (final line in yamlBlock.split('\n')) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) continue;
    final colon = trimmedLine.indexOf(':');
    if (colon <= 0) continue;
    final key = trimmedLine.substring(0, colon).trim();
    var value = trimmedLine.substring(colon + 1).trim();
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      value = value.substring(1, value.length - 1);
    }
    values[key] = value;
  }

  return ImportMarkdownData(
    body: body,
    sacId: values['sac_id'],
    title: values['title'],
    author: values['author'],
    project: values['project'],
    category: values['category'] ?? values['type'],
    tags: values['tags']?.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList() ?? const [],
    contentHash: values['content_hash']?.isNotEmpty == true
        ? values['content_hash']!
        : computeContentHash(body),
  );
}

/// 파일명에서 기본 title을 추출한다.
String titleFromRelativePath(String relativePath) {
  final base = p.basename(relativePath);
  return base.toLowerCase().endsWith('.md')
      ? base.substring(0, base.length - 3)
      : base;
}

/// sac_id를 생성한다.
String generateImportSacId(String contentHash) {
  final short = contentHash.length >= 8 ? contentHash.substring(0, 8) : contentHash;
  return 'sac_${DateTime.now().toUtc().millisecondsSinceEpoch}_$short';
}

/// frontmatter를 보강한 Markdown을 생성한다.
String buildImportFrontmatterMarkdown({
  required String sacId,
  required String workspaceId,
  required String body,
  String? title,
  String? author,
  String? project,
  String? category,
}) {
  final hash = computeContentHash(body);
  final indexedAt = DateTime.now().toUtc().toIso8601String();
  final lines = <String>[
    '---',
    'sac_id: "$sacId"',
    'sac_schema: "1"',
    'content_hash: "$hash"',
    'last_known_revision: 1',
    'last_indexed_at: "$indexedAt"',
    'source_workspace: "$workspaceId"',
  ];
  if (title != null && title.isNotEmpty) lines.add('title: "$title"');
  if (author != null && author.isNotEmpty) lines.add('author: "$author"');
  if (project != null && project.isNotEmpty) lines.add('project: "$project"');
  if (category != null && category.isNotEmpty) lines.add('category: "$category"');
  lines.add('---');
  lines.add(body);
  return lines.join('\n');
}
