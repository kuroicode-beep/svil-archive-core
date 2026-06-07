// document_chunker.dart — Markdown 본문을 검색용 chunk로 분할

class DocumentChunkData {
  final int chunkIndex;
  final String heading;
  final String content;

  const DocumentChunkData({
    required this.chunkIndex,
    required this.heading,
    required this.content,
  });
}

const int kMaxChunkLength = 1000;

/// Markdown 본문을 heading/문단 기준 chunk 목록으로 분할한다.
List<DocumentChunkData> chunkMarkdownBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) {
    return [
      const DocumentChunkData(chunkIndex: 0, heading: '', content: ''),
    ];
  }

  final sections = <({String heading, String content})>[];
  final lines = trimmed.split('\n');
  var currentHeading = '';
  final buffer = StringBuffer();

  void flushSection() {
    final text = buffer.toString().trim();
    if (text.isNotEmpty || currentHeading.isNotEmpty) {
      sections.add((heading: currentHeading, content: text));
    }
    buffer.clear();
  }

  for (final line in lines) {
    final headingMatch = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line.trim());
    if (headingMatch != null) {
      flushSection();
      currentHeading = headingMatch.group(2)!.trim();
      continue;
    }
    buffer.writeln(line);
  }
  flushSection();

  if (sections.isEmpty) {
    sections.add((heading: '', content: trimmed));
  }

  final chunks = <DocumentChunkData>[];
  var index = 0;
  for (final section in sections) {
    final parts = _splitLongText(section.content, kMaxChunkLength);
    if (parts.isEmpty) {
      chunks.add(DocumentChunkData(
        chunkIndex: index++,
        heading: section.heading,
        content: section.heading,
      ));
      continue;
    }
    for (final part in parts) {
      chunks.add(DocumentChunkData(
        chunkIndex: index++,
        heading: section.heading,
        content: part,
      ));
    }
  }
  return chunks;
}

/// 긴 텍스트를 최대 길이 단위로 분할한다.
List<String> _splitLongText(String text, int maxLength) {
  if (text.isEmpty) return const [];
  if (text.length <= maxLength) return [text];

  final parts = <String>[];
  var start = 0;
  while (start < text.length) {
    final end = (start + maxLength).clamp(0, text.length);
    parts.add(text.substring(start, end));
    start = end;
  }
  return parts;
}
