// document_import.dart — 파일 Import dry-run / 실행 결과 모델

/// Import 후보 상태.
enum ImportCandidateStatus {
  ready,
  skipRegistered,
  conflictSacId,
  duplicateHash,
  conflictTargetPath,
  invalid,
  copyRequired,
}

/// Import 후보 파일.
class ImportCandidate {
  final String relativePath;
  final String title;
  final String categoryPath;
  final String? existingSacId;
  final String? proposedSacId;
  final String contentHash;
  final ImportCandidateStatus status;
  final String? sourceAbsolutePath;
  final String? message;

  const ImportCandidate({
    required this.relativePath,
    required this.title,
    required this.categoryPath,
    this.existingSacId,
    this.proposedSacId,
    required this.contentHash,
    required this.status,
    this.sourceAbsolutePath,
    this.message,
  });

  bool get isImportable =>
      status == ImportCandidateStatus.ready ||
      status == ImportCandidateStatus.copyRequired;
}

/// Import 옵션.
class DocumentImportOptions {
  final List<String> absolutePaths;
  final bool includeSubfolders;
  final bool skipRegistered;
  final bool writeFrontmatter;
  final bool generateSacId;
  final bool dryRunOnly;

  const DocumentImportOptions({
    this.absolutePaths = const [],
    this.includeSubfolders = true,
    this.skipRegistered = true,
    this.writeFrontmatter = false,
    this.generateSacId = true,
    this.dryRunOnly = true,
  });

  DocumentImportOptions copyWith({
    List<String>? absolutePaths,
    bool? includeSubfolders,
    bool? skipRegistered,
    bool? writeFrontmatter,
    bool? generateSacId,
    bool? dryRunOnly,
  }) {
    return DocumentImportOptions(
      absolutePaths: absolutePaths ?? this.absolutePaths,
      includeSubfolders: includeSubfolders ?? this.includeSubfolders,
      skipRegistered: skipRegistered ?? this.skipRegistered,
      writeFrontmatter: writeFrontmatter ?? this.writeFrontmatter,
      generateSacId: generateSacId ?? this.generateSacId,
      dryRunOnly: dryRunOnly ?? this.dryRunOnly,
    );
  }

  /// dry-run과 execute 일치 검증용 fingerprint.
  String get fingerprint => buildImportOptionsFingerprint(this);
}

/// Import 옵션 fingerprint를 생성한다.
String buildImportOptionsFingerprint(DocumentImportOptions options) {
  final paths = List<String>.from(options.absolutePaths)..sort();
  return [
    paths.join('|'),
    options.includeSubfolders,
    options.skipRegistered,
    options.writeFrontmatter,
    options.generateSacId,
  ].join('::');
}

/// 사용자가 확인한 dry-run snapshot.
class ImportApprovedSnapshot {
  final DocumentImportOptions options;
  final ImportDryRunResult preview;

  const ImportApprovedSnapshot({
    required this.options,
    required this.preview,
  });

  String get fingerprint => options.fingerprint;

  List<ImportCandidate> get importableCandidates =>
      preview.candidates.where((c) => c.isImportable).toList();
}

/// dry-run 결과.
class ImportDryRunResult {
  final List<ImportCandidate> candidates;
  final int readyCount;
  final int skipCount;
  final int conflictCount;
  final int duplicateCount;
  final int invalidCount;

  const ImportDryRunResult({
    required this.candidates,
    required this.readyCount,
    required this.skipCount,
    required this.conflictCount,
    required this.duplicateCount,
    required this.invalidCount,
  });
}

/// Import 실행 결과.
class ImportExecutionResult {
  final bool dryRun;
  final int registeredCount;
  final int failedCount;
  final int skippedCount;
  final String? backupPath;
  final String? reportPath;
  final List<String> registeredDocumentIds;
  final List<String> failures;
  final ImportDryRunResult preview;

  const ImportExecutionResult({
    required this.dryRun,
    required this.registeredCount,
    required this.failedCount,
    required this.skippedCount,
    this.backupPath,
    this.reportPath,
    this.registeredDocumentIds = const [],
    this.failures = const [],
    required this.preview,
  });
}
