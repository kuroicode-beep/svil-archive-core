// llm_self_info_export_service_impl.dart — LLM 자기정보 export 구현

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/dashboard.dart';
import '../../domain/models/personal_archive.dart';
import '../../domain/services/llm_self_info_export_service.dart';
import '../db/database_service_impl.dart';
import '../platform/path_adapter.dart';

class LlmSelfInfoExportServiceImpl implements LlmSelfInfoExportService {
  final DatabaseServiceImpl _databaseService;
  final String workspaceRoot;
  final Uuid _uuid = const Uuid();

  LlmSelfInfoExportServiceImpl({
    required DatabaseServiceImpl databaseService,
    required this.workspaceRoot,
  }) : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<LlmSelfInfoExportResult> buildPreview({LlmSelfInfoExportOptions? options}) async {
    final built = await _buildExportContent(options ?? const LlmSelfInfoExportOptions());
    return built;
  }

  @override
  Future<LlmSelfInfoExportResult> exportToFile({LlmSelfInfoExportOptions? options}) async {
    final built = await _buildExportContent(options ?? const LlmSelfInfoExportOptions());
    final exportDir = Directory(llmSelfInfoExportDirectory(workspaceRoot));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final file = File(p.join(exportDir.path, p.basename(built.relativePath)));
    await file.writeAsString(built.previewMarkdown);
    await _auditExport(built.relativePath, built.includedItemCount);
    return LlmSelfInfoExportResult(
      relativePath: built.relativePath,
      absolutePath: file.path,
      previewMarkdown: built.previewMarkdown,
      includedItemCount: built.includedItemCount,
      excludedPendingCount: built.excludedPendingCount,
      excludedRejectedCount: built.excludedRejectedCount,
      excludedDeletedCount: built.excludedDeletedCount,
    );
  }

  /// active 항목만 포함한 export 본문을 생성한다.
  Future<LlmSelfInfoExportResult> _buildExportContent(LlmSelfInfoExportOptions options) async {
    final activeItems = await _loadActiveArchiveItems();
    final journalItems = await _loadSelectedJournalComments(options.journalCommentIds);
    final excluded = await _countExcludedCandidates();

    final now = DateTime.now();
    final stamp = _formatFileStamp(now);
    final relativePath = p.posix.join('.sac', 'exports', 'llm_self_info_$stamp.md');
    final markdown = _composeMarkdown(
      generatedAt: now,
      items: activeItems,
      journals: journalItems,
      excluded: excluded,
    );

    return LlmSelfInfoExportResult(
      relativePath: relativePath,
      absolutePath: resolveWorkspacePath(workspaceRoot, relativePath),
      previewMarkdown: markdown,
      includedItemCount: activeItems.length + journalItems.length,
      excludedPendingCount: excluded.$1,
      excludedRejectedCount: excluded.$2,
      excludedDeletedCount: excluded.$3,
    );
  }

  /// active personal_archive_items만 조회한다.
  Future<List<PersonalArchiveItem>> _loadActiveArchiveItems() async {
    final rows = await _db.query(
      'personal_archive_items',
      where: "status = ?",
      whereArgs: [PersonalArchiveItemStatus.active.name],
      orderBy: 'updated_at DESC',
    );
    return rows.map(_mapArchiveItem).toList();
  }

  /// 사용자가 선택한 일지 코멘트만 조회한다.
  Future<List<JournalComment>> _loadSelectedJournalComments(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await _db.query(
      'journal_comments',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'updated_at DESC',
    );
    return rows.map(_mapJournal).toList();
  }

  /// 제외 대상 후보/삭제 항목 수를 집계한다 (export 미포함 확인용).
  Future<(int, int, int)> _countExcludedCandidates() async {
    final pending = Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM personal_extraction_queue WHERE status = 'pending'",
          ),
        ) ??
        0;
    final rejected = Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM personal_extraction_queue WHERE status = 'rejected'",
          ),
        ) ??
        0;
    final deleted = Sqflite.firstIntValue(
          await _db.rawQuery(
            "SELECT COUNT(*) FROM personal_archive_items WHERE status = 'deleted'",
          ),
        ) ??
        0;
    return (pending, rejected, deleted);
  }

  /// Markdown 본문을 조합한다.
  String _composeMarkdown({
    required DateTime generatedAt,
    required List<PersonalArchiveItem> items,
    required List<JournalComment> journals,
    required (int, int, int) excluded,
  }) {
    final dateLabel = _formatDisplayDate(generatedAt);
    final buffer = StringBuffer()
      ..writeln('# LLM Self Info Export')
      ..writeln()
      ..writeln('생성일: $dateLabel')
      ..writeln('출처: SAC local personal archive')
      ..writeln('범위: approved / active only')
      ..writeln()
      ..writeln('## 01. 기본 정보');

    final profiles = items.where((i) => i.itemType == 'profile').toList();
    if (profiles.isEmpty) {
      buffer.writeln('- (없음)');
    } else {
      for (final item in profiles) {
        buffer.writeln('- **${item.title}**: ${item.content}');
      }
    }

    buffer.writeln();
    buffer.writeln('## 02. 관심분야');
    _writeSection(buffer, items, 'interest');

    buffer.writeln();
    buffer.writeln('## 03. 프로젝트');
    _writeSection(buffer, items, 'project');

    buffer.writeln();
    buffer.writeln('## 04. 응답 선호');
    _writeSection(buffer, items, 'preference');

    buffer.writeln();
    buffer.writeln('## 05. 접근성 기준');
    _writeSection(buffer, items, 'accessibility');

    if (journals.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## 06. 일지 코멘트 (선택 포함)');
      for (final journal in journals) {
        buffer.writeln('- **${journal.title}**: ${journal.content}');
      }
    }

    buffer
      ..writeln()
      ..writeln('## 제외된 정보')
      ..writeln('- pending 후보 제외: ${excluded.$1}건')
      ..writeln('- rejected 후보 제외: ${excluded.$2}건')
      ..writeln('- deleted 항목 제외: ${excluded.$3}건');

    final otherItems = items
        .where((i) => !{'profile', 'interest', 'project', 'preference', 'accessibility', 'approved'}
            .contains(i.itemType))
        .toList();
    if (otherItems.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## 기타 승인 항목');
      for (final item in otherItems) {
        buffer.writeln('- **${item.title}** (${item.itemType}): ${item.content}');
      }
    }

    return buffer.toString();
  }

  /// 섹션별 항목을 기록한다.
  void _writeSection(StringBuffer buffer, List<PersonalArchiveItem> items, String type) {
    final section = items.where((i) => i.itemType == type).toList();
    if (section.isEmpty) {
      buffer.writeln('- (없음)');
      return;
    }
    for (final item in section) {
      buffer.writeln('- **${item.title}**: ${item.content}');
    }
  }

  /// export 경로만 감사 로그에 기록한다.
  Future<void> _auditExport(String relativePath, int itemCount) async {
    await _db.insert('audit_logs', {
      'id': _uuid.v4(),
      'actor': 'user',
      'action': 'export',
      'target_type': 'llm_self_info',
      'target_id': relativePath,
      'detail_json': '{"item_count":$itemCount}',
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// 파일명용 타임스탬프를 생성한다.
  String _formatFileStamp(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}_${two(dt.hour)}${two(dt.minute)}';
  }

  /// 화면 표시용 날짜 문자열을 생성한다.
  String _formatDisplayDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}.${two(dt.month)}.${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  /// DB row를 PersonalArchiveItem으로 변환한다.
  PersonalArchiveItem _mapArchiveItem(Map<String, Object?> row) {
    return PersonalArchiveItem(
      id: row['id'] as String,
      itemType: row['item_type'] as String,
      title: row['title'] as String,
      content: row['content'] as String,
      sourceDocumentId: row['source_document_id'] as String?,
      sourcePath: row['source_path'] as String?,
      confidence: (row['confidence'] as num?)?.toDouble(),
      status: PersonalArchiveItemStatus.values.firstWhere(
        (s) => s.name == (row['status'] as String? ?? 'active'),
        orElse: () => PersonalArchiveItemStatus.active,
      ),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }

  /// DB row를 JournalComment로 변환한다.
  JournalComment _mapJournal(Map<String, Object?> row) {
    final tagsRaw = row['tags'] as String?;
    List<String> tags = const [];
    if (tagsRaw != null && tagsRaw.isNotEmpty) {
      tags = tagsRaw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    }
    return JournalComment(
      id: row['id'] as String,
      title: row['title'] as String,
      content: row['content'] as String,
      mood: row['mood'] as String?,
      tags: tags,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }
}
