// journal_comment_service_impl.dart — 일지 코멘트 SQLite 구현

import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/personal_archive.dart';
import '../../domain/services/journal_comment_service.dart';
import '../db/database_service_impl.dart';

class JournalCommentServiceImpl implements JournalCommentService {
  final DatabaseServiceImpl _databaseService;
  final Uuid _uuid = const Uuid();

  JournalCommentServiceImpl({required DatabaseServiceImpl databaseService})
      : _databaseService = databaseService;

  Database get _db => _databaseService.requireDatabase();

  @override
  Future<List<JournalComment>> listComments() async {
    final rows = await _db.query('journal_comments', orderBy: 'updated_at DESC');
    return rows.map(_mapComment).toList();
  }

  @override
  Future<JournalComment> createComment(CreateJournalCommentInput input) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert('journal_comments', {
      'id': id,
      'title': input.title,
      'content': input.content,
      'mood': input.mood,
      'tags': jsonEncode(input.tags),
      'created_at': now,
      'updated_at': now,
    });
    return JournalComment(
      id: id,
      title: input.title,
      content: input.content,
      mood: input.mood,
      tags: input.tags,
      createdAt: DateTime.parse(now).toLocal(),
      updatedAt: DateTime.parse(now).toLocal(),
    );
  }

  @override
  Future<JournalComment> updateComment(UpdateJournalCommentInput input) async {
    final rows = await _db.query(
      'journal_comments',
      where: 'id = ?',
      whereArgs: [input.id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Journal comment not found: ${input.id}');

    final existing = _mapComment(rows.first);
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = JournalComment(
      id: existing.id,
      title: input.title ?? existing.title,
      content: input.content ?? existing.content,
      mood: input.mood ?? existing.mood,
      tags: input.tags ?? existing.tags,
      createdAt: existing.createdAt,
      updatedAt: DateTime.parse(now).toLocal(),
    );

    await _db.update(
      'journal_comments',
      {
        'title': updated.title,
        'content': updated.content,
        'mood': updated.mood,
        'tags': jsonEncode(updated.tags),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [input.id],
    );
    return updated;
  }

  @override
  Future<void> deleteComment(String id) async {
    await _db.delete('journal_comments', where: 'id = ?', whereArgs: [id]);
  }

  /// DB row를 JournalComment로 변환한다.
  JournalComment _mapComment(Map<String, Object?> row) {
    final tagsRaw = row['tags'] as String?;
    List<String> tags = const [];
    if (tagsRaw != null && tagsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(tagsRaw);
        if (decoded is List) tags = decoded.map((e) => e.toString()).toList();
      } catch (_) {
        tags = const [];
      }
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
