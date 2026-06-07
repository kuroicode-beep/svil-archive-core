// personal_archive.dart — 개인 아카이브 / 추출 대기열 / 일지 도메인 모델

enum PersonalArchiveItemStatus { active, archived, deleted }

enum ExtractionQueueStatus { pending, approved, rejected, editedApproved }

class PersonalArchiveItem {
  final String id;
  final String itemType;
  final String title;
  final String content;
  final String? sourceDocumentId;
  final String? sourcePath;
  final double? confidence;
  final PersonalArchiveItemStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonalArchiveItem({
    required this.id,
    required this.itemType,
    required this.title,
    required this.content,
    this.sourceDocumentId,
    this.sourcePath,
    this.confidence,
    this.status = PersonalArchiveItemStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });
}

class ExtractionCandidate {
  final String id;
  final String? sourceDocumentId;
  final String? sourcePath;
  final String candidateType;
  final String candidateTitle;
  final String candidateContent;
  final double? confidence;
  final String? reason;
  final ExtractionQueueStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExtractionCandidate({
    required this.id,
    this.sourceDocumentId,
    this.sourcePath,
    required this.candidateType,
    required this.candidateTitle,
    required this.candidateContent,
    this.confidence,
    this.reason,
    this.status = ExtractionQueueStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });
}

class JournalComment {
  final String id;
  final String title;
  final String content;
  final String? mood;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JournalComment({
    required this.id,
    required this.title,
    required this.content,
    this.mood,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });
}

class CreatePersonalArchiveItemInput {
  final String itemType;
  final String title;
  final String content;

  const CreatePersonalArchiveItemInput({
    required this.itemType,
    required this.title,
    required this.content,
  });
}

class UpdatePersonalArchiveItemInput {
  final String id;
  final String? title;
  final String? content;
  final String? itemType;

  const UpdatePersonalArchiveItemInput({
    required this.id,
    this.title,
    this.content,
    this.itemType,
  });
}

class CreateExtractionCandidateInput {
  final String? sourceDocumentId;
  final String? sourcePath;
  final String candidateType;
  final String candidateTitle;
  final String candidateContent;
  final double? confidence;
  final String? reason;

  const CreateExtractionCandidateInput({
    this.sourceDocumentId,
    this.sourcePath,
    required this.candidateType,
    required this.candidateTitle,
    required this.candidateContent,
    this.confidence,
    this.reason,
  });
}

class EditExtractionCandidateInput {
  final String candidateId;
  final String title;
  final String content;
  final String? itemType;

  const EditExtractionCandidateInput({
    required this.candidateId,
    required this.title,
    required this.content,
    this.itemType,
  });
}

class CreateJournalCommentInput {
  final String title;
  final String content;
  final String? mood;
  final List<String> tags;

  const CreateJournalCommentInput({
    required this.title,
    required this.content,
    this.mood,
    this.tags = const [],
  });
}

class UpdateJournalCommentInput {
  final String id;
  final String? title;
  final String? content;
  final String? mood;
  final List<String>? tags;

  const UpdateJournalCommentInput({
    required this.id,
    this.title,
    this.content,
    this.mood,
    this.tags,
  });
}
