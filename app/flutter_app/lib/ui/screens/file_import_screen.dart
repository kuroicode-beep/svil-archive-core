// file_import_screen.dart — 파일 Import dry-run / 정식 등록 (Sprint 15, 16H-3)

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../domain/models/document_import.dart';
import '../../domain/services/document_import_service.dart';

class FileImportScreen extends StatefulWidget {
  final DocumentImportService importService;
  final VoidCallback? onImportCompleted;

  const FileImportScreen({
    super.key,
    required this.importService,
    this.onImportCompleted,
  });

  @override
  State<FileImportScreen> createState() => _FileImportScreenState();
}

class _FileImportScreenState extends State<FileImportScreen> {
  bool _includeSubfolders = true;
  bool _skipRegistered = true;
  bool _writeFrontmatter = false;
  bool _generateSacId = true;
  bool _dryRunInProgress = false;
  bool _executeInProgress = false;
  ImportApprovedSnapshot? _approvedSnapshot;
  ImportExecutionResult? _lastResult;
  String? _lastDryRunError;
  final List<String> _selectedPaths = [];
  final _scrollController = ScrollController();
  final _resultSectionKey = GlobalKey();

  DocumentImportOptions get _options => DocumentImportOptions(
        absolutePaths: List<String>.from(_selectedPaths),
        includeSubfolders: _includeSubfolders,
        skipRegistered: _skipRegistered,
        writeFrontmatter: _writeFrontmatter,
        generateSacId: _generateSacId,
        dryRunOnly: true,
      );

  /// dry-run snapshot을 무효화한다.
  void _invalidateSnapshot() {
    _approvedSnapshot = null;
  }

  /// 옵션 변경 시 snapshot은 유지하고 실행 가능 여부만 갱신한다.
  void _onOptionsChanged(VoidCallback update) {
    final hadValidSnapshot = _approvedSnapshot != null &&
        _approvedSnapshot!.options.fingerprint == _options.fingerprint;
    setState(() {
      update();
      _lastResult = null;
    });
    if (hadValidSnapshot && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이전 dry-run 결과가 무효화되었습니다. 다시 dry-run 해주세요.'),
        ),
      );
    }
  }

  /// 선택 경로가 읽을 수 있는지 검사한다.
  Future<String?> _validateSelectedPaths() async {
    if (_selectedPaths.isEmpty) {
      return '파일 또는 폴더를 먼저 선택하세요.';
    }
    for (final raw in _selectedPaths) {
      final path = p.normalize(raw);
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        return '경로를 찾을 수 없습니다: $path';
      }
      if (type == FileSystemEntityType.directory) {
        try {
          await Directory(path).list(followLinks: false).first;
        } catch (e) {
          return '폴더를 읽을 수 없습니다: $path ($e)';
        }
      }
    }
    return null;
  }

  /// dry-run 결과 영역으로 스크롤한다.
  void _scrollToResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _resultSectionKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// dry-run preview를 실행하고 snapshot을 고정한다.
  Future<void> _runDryRun({bool workspaceOrphans = false}) async {
    if (!workspaceOrphans) {
      final pathError = await _validateSelectedPaths();
      if (pathError != null) {
        setState(() {
          _lastDryRunError = pathError;
          _invalidateSnapshot();
          _lastResult = null;
        });
        _scrollToResults();
        return;
      }
    }

    setState(() {
      _dryRunInProgress = true;
      _lastDryRunError = null;
      _invalidateSnapshot();
      _lastResult = null;
    });
    try {
      final options = _options;
      final preview = workspaceOrphans
          ? await widget.importService.scanWorkspaceOrphans(options)
          : await widget.importService.dryRun(options);
      if (!mounted) return;
      setState(() {
        _approvedSnapshot = ImportApprovedSnapshot(
          options: options.copyWith(dryRunOnly: false),
          preview: preview,
        );
      });
      _scrollToResults();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _invalidateSnapshot();
        _lastDryRunError = e.toString();
      });
      _scrollToResults();
    } finally {
      if (mounted) setState(() => _dryRunInProgress = false);
    }
  }

  /// snapshot에 고정된 후보만 정식 등록한다.
  Future<void> _runExecute() async {
    final snapshot = _approvedSnapshot;
    if (snapshot == null || snapshot.preview.readyCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 미리 검사를 실행하고 등록 대상이 있어야 합니다.')),
      );
      return;
    }
    if (snapshot.options.fingerprint != _options.fingerprint) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('옵션 또는 경로가 변경되었습니다. 미리 검사를 다시 실행하세요.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('정식 등록 실행'),
        content: Text(
          '확인한 등록 대상 ${snapshot.preview.readyCount}건을 SQLite에 등록합니다.\n'
          'DB 백업 후 진행하며 원본 파일은 이동/삭제하지 않습니다.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('실행')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _executeInProgress = true);
    try {
      final result = await widget.importService.executeApprovedImport(snapshot);
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _invalidateSnapshot();
      });
      widget.onImportCompleted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록 완료: ${result.registeredCount}건')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _executeInProgress = false);
    }
  }

  /// 파일 선택 다이얼로그를 연다.
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md'],
      allowMultiple: true,
    );
    if (result == null) return;
    _onOptionsChanged(() {
      _selectedPaths
        ..clear()
        ..addAll(result.paths.whereType<String>());
      _lastDryRunError = null;
    });
  }

  /// 폴더 선택 다이얼로그를 연다.
  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    _onOptionsChanged(() {
      _selectedPaths
        ..clear()
        ..add(path);
      _lastDryRunError = null;
    });
  }

  /// dry-run 결과 안내 문구를 반환한다.
  String? _resultGuidance(ImportDryRunResult preview) {
    final total = preview.candidates.length;
    if (total == 0) {
      return 'Markdown 파일을 찾지 못했습니다. .md 파일이 있는 폴더인지 확인하세요.';
    }
    if (preview.readyCount == 0) {
      if (preview.skipCount == total) {
        return '등록 가능한 새 파일이 없습니다. 이미 모두 등록된 파일입니다.';
      }
      if (preview.conflictCount > 0 || preview.invalidCount > 0) {
        return '등록 가능한 새 파일이 없습니다. conflict/error 항목을 확인하세요.';
      }
      return '등록 가능한 새 파일이 없습니다.';
    }
    return null;
  }

  /// 상단 요약 카드를 구성한다.
  Widget _buildSummaryCard({
    required ImportDryRunResult? preview,
    required bool canExecute,
    required bool approved,
  }) {
    final theme = Theme.of(context);
    if (_dryRunInProgress) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Dry-run 진행 중... 선택 경로를 스캔하고 있습니다.',
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_lastDryRunError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dry-run 오류',
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _lastDryRunError!,
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (preview == null) {
      if (_selectedPaths.isEmpty) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '파일 또는 폴더를 선택한 뒤 미리 검사(dry-run)를 실행하세요.',
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
            ),
          ),
        );
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '선택 경로가 준비되었습니다. 미리 검사(dry-run)를 실행하면 결과가 여기에 표시됩니다.',
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
          ),
        ),
      );
    }

    final total = preview.candidates.length;
    final guidance = _resultGuidance(preview);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approved
                  ? 'Dry-run 결과 (정식 등록 가능)'
                  : 'Dry-run 결과 (재검사 필요)',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Dry-run 결과: 후보 $total / 등록 가능 ${preview.readyCount} / '
              'skip ${preview.skipCount} / conflict ${preview.conflictCount} / '
              'error ${preview.invalidCount}',
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
            ),
            if (guidance != null) ...[
              const SizedBox(height: 8),
              Text(
                guidance,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (!canExecute && preview.readyCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '옵션 또는 경로가 변경되었습니다. 미리 검사를 다시 실행하세요.',
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _approvedSnapshot;
    final preview = snapshot?.preview;
    final result = _lastResult;
    final canExecute = snapshot != null &&
        snapshot.preview.readyCount > 0 &&
        snapshot.options.fingerprint == _options.fingerprint;
    final actionLocked = _dryRunInProgress || _executeInProgress;
    final approved = snapshot != null && canExecute;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '파일 Import',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Markdown을 SAC에 정식 등록합니다. dry-run 후 동일 snapshot으로만 실행하세요.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _executeInProgress ? null : _pickFiles,
                  child: const Text('파일 선택'),
                ),
              ),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _executeInProgress ? null : _pickFolder,
                  child: const Text('폴더 선택'),
                ),
              ),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: actionLocked ? null : () => _runDryRun(workspaceOrphans: true),
                  child: const Text('Workspace orphan 스캔'),
                ),
              ),
            ],
          ),
          if (_selectedPaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('선택 경로 (${_selectedPaths.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ..._selectedPaths.take(5).map((path) => Text(path, style: const TextStyle(fontSize: 16))),
            if (_selectedPaths.length > 5)
              Text('외 ${_selectedPaths.length - 5}개', style: const TextStyle(fontSize: 16)),
          ],
          const SizedBox(height: 12),
          _buildSummaryCard(preview: preview, canExecute: canExecute, approved: approved),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('하위 폴더 포함', style: TextStyle(fontSize: 16)),
            value: _includeSubfolders,
            onChanged: _executeInProgress
                ? null
                : (v) => _onOptionsChanged(() => _includeSubfolders = v),
          ),
          SwitchListTile(
            title: const Text('이미 등록된 파일 skip', style: TextStyle(fontSize: 16)),
            value: _skipRegistered,
            onChanged: _executeInProgress
                ? null
                : (v) => _onOptionsChanged(() => _skipRegistered = v),
          ),
          SwitchListTile(
            title: const Text('sac_id 없으면 생성', style: TextStyle(fontSize: 16)),
            value: _generateSacId,
            onChanged: _executeInProgress
                ? null
                : (v) => _onOptionsChanged(() => _generateSacId = v),
          ),
          SwitchListTile(
            title: const Text('frontmatter 보강 쓰기 (확인 후)', style: TextStyle(fontSize: 16)),
            subtitle: const Text('기존 frontmatter 자동 덮어쓰기 금지 — sac_id 없을 때만', style: TextStyle(fontSize: 16)),
            value: _writeFrontmatter,
            onChanged: _executeInProgress
                ? null
                : (v) => _onOptionsChanged(() => _writeFrontmatter = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: actionLocked ? null : () => _runDryRun(),
                    child: Text(_dryRunInProgress ? '처리 중...' : '미리 검사 (dry-run)'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (actionLocked || !canExecute) ? null : _runExecute,
                    child: const Text('정식 등록 실행'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: _resultSectionKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (preview != null) _buildPreviewCard(preview, approved: approved),
                if (result != null && !result.dryRun) _buildResultCard(result),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// dry-run 상세 카드를 구성한다.
  Widget _buildPreviewCard(ImportDryRunResult preview, {required bool approved}) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approved ? '미리 검사 상세 (실행 가능)' : '미리 검사 상세 (재검사 필요)',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('후보 파일: ${preview.candidates.length}건', style: const TextStyle(fontSize: 16)),
            Text('등록 가능: ${preview.readyCount}건', style: const TextStyle(fontSize: 16)),
            Text('skip: ${preview.skipCount}건', style: const TextStyle(fontSize: 16)),
            Text('conflict: ${preview.conflictCount}건', style: const TextStyle(fontSize: 16)),
            Text('duplicate: ${preview.duplicateCount}건', style: const TextStyle(fontSize: 16)),
            Text('error: ${preview.invalidCount}건', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            ...preview.candidates.take(12).map(
                  (c) => ListTile(
                    dense: true,
                    title: Text(c.relativePath, style: const TextStyle(fontSize: 16)),
                    subtitle: Text(
                      '${c.status.name}${c.message == null ? '' : ' — ${c.message}'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
            if (preview.candidates.length > 12)
              Text('외 ${preview.candidates.length - 12}건', style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  /// 실행 결과 카드를 구성한다.
  Widget _buildResultCard(ImportExecutionResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('등록 완료', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('등록: ${result.registeredCount}건', style: const TextStyle(fontSize: 16)),
            Text('실패: ${result.failedCount}건', style: const TextStyle(fontSize: 16)),
            if (result.backupPath != null)
              Text('백업: ${result.backupPath}', style: const TextStyle(fontSize: 16)),
            if (result.reportPath != null)
              Text('리포트: ${result.reportPath}', style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
