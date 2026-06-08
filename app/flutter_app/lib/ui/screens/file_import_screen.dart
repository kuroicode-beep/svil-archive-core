// file_import_screen.dart — 파일 Import dry-run / 정식 등록 (Sprint 15)

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
  bool _busy = false;
  ImportDryRunResult? _preview;
  ImportExecutionResult? _lastResult;
  final List<String> _selectedPaths = [];

  DocumentImportOptions get _options => DocumentImportOptions(
        absolutePaths: List<String>.from(_selectedPaths),
        includeSubfolders: _includeSubfolders,
        skipRegistered: _skipRegistered,
        writeFrontmatter: _writeFrontmatter,
        generateSacId: _generateSacId,
        dryRunOnly: true,
      );

  /// dry-run preview를 실행한다.
  Future<void> _runDryRun({bool workspaceOrphans = false}) async {
    setState(() => _busy = true);
    try {
      final preview = workspaceOrphans
          ? await widget.importService.scanWorkspaceOrphans(_options)
          : await widget.importService.dryRun(_options);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _lastResult = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('미리 검사 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 정식 등록을 실행한다.
  Future<void> _runExecute() async {
    if (_preview == null || _preview!.readyCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 미리 검사를 실행하고 등록 대상이 있어야 합니다.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('정식 등록 실행'),
        content: Text(
          '등록 대상 ${_preview!.readyCount}건을 SQLite에 등록합니다.\n'
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

    setState(() => _busy = true);
    try {
      final result = await widget.importService.executeImport(
        _options.copyWith(dryRunOnly: false),
      );
      if (!mounted) return;
      setState(() => _lastResult = result);
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
      if (mounted) setState(() => _busy = false);
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
    setState(() {
      _selectedPaths
        ..clear()
        ..addAll(result.paths.whereType<String>());
    });
  }

  /// 폴더 선택 다이얼로그를 연다.
  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    setState(() {
      _selectedPaths
        ..clear()
        ..add(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final result = _lastResult;
    return SingleChildScrollView(
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
            'Markdown을 SAC에 정식 등록합니다. dry-run 후 실행하세요. 원본 이동/삭제 없음.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                height: 50,
                child: OutlinedButton(onPressed: _busy ? null : _pickFiles, child: const Text('파일 선택')),
              ),
              SizedBox(
                height: 50,
                child: OutlinedButton(onPressed: _busy ? null : _pickFolder, child: const Text('폴더 선택')),
              ),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _runDryRun(workspaceOrphans: true),
                  child: const Text('Workspace orphan 스캔'),
                ),
              ),
            ],
          ),
          if (_selectedPaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('선택 경로 (${_selectedPaths.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ..._selectedPaths.take(5).map((p) => Text(p, style: const TextStyle(fontSize: 16))),
            if (_selectedPaths.length > 5)
              Text('외 ${_selectedPaths.length - 5}개', style: const TextStyle(fontSize: 16)),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('하위 폴더 포함', style: TextStyle(fontSize: 16)),
            value: _includeSubfolders,
            onChanged: _busy ? null : (v) => setState(() => _includeSubfolders = v),
          ),
          SwitchListTile(
            title: const Text('이미 등록된 파일 skip', style: TextStyle(fontSize: 16)),
            value: _skipRegistered,
            onChanged: _busy ? null : (v) => setState(() => _skipRegistered = v),
          ),
          SwitchListTile(
            title: const Text('sac_id 없으면 생성', style: TextStyle(fontSize: 16)),
            value: _generateSacId,
            onChanged: _busy ? null : (v) => setState(() => _generateSacId = v),
          ),
          SwitchListTile(
            title: const Text('frontmatter 보강 쓰기 (확인 후)', style: TextStyle(fontSize: 16)),
            subtitle: const Text('기존 frontmatter 자동 덮어쓰기 금지 — sac_id 없을 때만', style: TextStyle(fontSize: 16)),
            value: _writeFrontmatter,
            onChanged: _busy ? null : (v) => setState(() => _writeFrontmatter = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _runDryRun(),
                    child: Text(_busy ? '처리 중...' : '미리 검사 (dry-run)'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_busy || preview == null || preview.readyCount == 0) ? null : _runExecute,
                    child: const Text('정식 등록 실행'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (preview != null) _buildPreviewCard(preview),
          if (result != null && !result.dryRun) _buildResultCard(result),
        ],
      ),
    );
  }

  /// dry-run 요약 카드를 구성한다.
  Widget _buildPreviewCard(ImportDryRunResult preview) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('미리 검사 결과', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('등록 가능: ${preview.readyCount}건', style: const TextStyle(fontSize: 16)),
            Text('skip: ${preview.skipCount}건', style: const TextStyle(fontSize: 16)),
            Text('conflict: ${preview.conflictCount}건', style: const TextStyle(fontSize: 16)),
            Text('duplicate: ${preview.duplicateCount}건', style: const TextStyle(fontSize: 16)),
            Text('invalid: ${preview.invalidCount}건', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            ...preview.candidates.where((c) => c.isImportable).take(8).map(
                  (c) => ListTile(
                    dense: true,
                    title: Text(c.relativePath, style: const TextStyle(fontSize: 16)),
                    subtitle: Text(
                      '${c.status.name} · ${c.categoryPath.isEmpty ? "(root)" : c.categoryPath}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
            if (preview.readyCount > 8)
              Text('외 ${preview.readyCount - 8}건', style: const TextStyle(fontSize: 16)),
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
