// frontmatter_parser_test.dart — frontmatter 파싱 단위 테스트

import 'package:flutter_test/flutter_test.dart';
import 'package:sac_app/data/file/content_hasher.dart';
import 'package:sac_app/data/file/frontmatter_parser.dart';

void main() {
  test('parseMarkdownWithFrontmatter extracts body and metadata', () {
    const raw = '''---
sac_id: "doc-1"
sac_schema: "1"
content_hash: "abc"
last_known_revision: 2
last_indexed_at: "2026-06-05T00:00:00Z"
source_workspace: "ws-1"
---
# Hello
World''';

    final parsed = parseMarkdownWithFrontmatter(raw);
    expect(parsed.sacId, 'doc-1');
    expect(parsed.lastKnownRevision, 2);
    expect(parsed.body, '# Hello\nWorld');
  });

  test('buildMarkdownWithFrontmatter computes hash', () {
    final markdown = buildMarkdownWithFrontmatter(
      sacId: 'doc-2',
      sacSchema: '1',
      body: 'body text',
      revision: 1,
      sourceWorkspace: 'ws-2',
    );
    expect(markdown.startsWith('---'), isTrue);
    final parsed = parseMarkdownWithFrontmatter(markdown);
    expect(parsed.contentHash, computeContentHash('body text'));
  });
}
