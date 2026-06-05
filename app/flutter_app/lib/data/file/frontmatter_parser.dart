// frontmatter_parser.dart — Markdown frontmatter 파싱/직렬화

import '../../domain/models/document.dart';
import 'content_hasher.dart';

class FrontmatterData {
  final String sacId;
  final String sacSchema;
  final String contentHash;
  final int lastKnownRevision;
  final String lastIndexedAt;
  final String sourceWorkspace;
  final String body;

  const FrontmatterData({
    required this.sacId,
    required this.sacSchema,
    required this.contentHash,
    required this.lastKnownRevision,
    required this.lastIndexedAt,
    required this.sourceWorkspace,
    required this.body,
  });
}

class FrontmatterParseException implements Exception {
  final String message;
  const FrontmatterParseException(this.message);

  @override
  String toString() => 'FrontmatterParseException: $message';
}

/// Markdown 전체 문자열에서 frontmatter와 본문을 분리한다.
FrontmatterData parseMarkdownWithFrontmatter(String raw) {
  final trimmed = raw.replaceFirst('\uFEFF', '');
  if (!trimmed.startsWith('---')) {
    throw const FrontmatterParseException('Missing opening frontmatter delimiter');
  }

  final endIndex = trimmed.indexOf('\n---', 3);
  if (endIndex < 0) {
    throw const FrontmatterParseException('Missing closing frontmatter delimiter');
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

  final sacId = values['sac_id'];
  if (sacId == null || sacId.isEmpty) {
    throw const FrontmatterParseException('sac_id is required');
  }

  return FrontmatterData(
    sacId: sacId,
    sacSchema: values['sac_schema'] ?? '1',
    contentHash: values['content_hash'] ?? '',
    lastKnownRevision: int.tryParse(values['last_known_revision'] ?? '1') ?? 1,
    lastIndexedAt: values['last_indexed_at'] ?? DateTime.now().toUtc().toIso8601String(),
    sourceWorkspace: values['source_workspace'] ?? '',
    body: body,
  );
}

/// frontmatter와 본문을 포함한 Markdown 문자열을 생성한다.
String buildMarkdownWithFrontmatter({
  required String sacId,
  required String sacSchema,
  required String body,
  required int revision,
  required String sourceWorkspace,
}) {
  final hash = computeContentHash(body);
  final indexedAt = DateTime.now().toUtc().toIso8601String();
  return '''---
sac_id: "$sacId"
sac_schema: "$sacSchema"
content_hash: "$hash"
last_known_revision: $revision
last_indexed_at: "$indexedAt"
source_workspace: "$sourceWorkspace"
---
$body''';
}

/// frontmatter 데이터를 DocumentMetadata 초안으로 변환한다.
DocumentMetadata toMetadataDraft({
  required FrontmatterData frontmatter,
  required String relativePath,
  required String title,
  String? category,
}) {
  return DocumentMetadata(
    id: frontmatter.sacId,
    path: relativePath,
    title: title,
    type: category,
    status: DocumentStatus.active,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    contentHash: frontmatter.contentHash.isNotEmpty
        ? frontmatter.contentHash
        : computeContentHash(frontmatter.body),
    revision: frontmatter.lastKnownRevision,
    sacSchema: frontmatter.sacSchema,
  );
}
