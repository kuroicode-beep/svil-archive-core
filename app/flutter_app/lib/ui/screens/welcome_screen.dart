// welcome_screen.dart — Workspace 생성/열기 화면

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../application/sac_container.dart';
import '../../domain/models/workspace.dart';
import 'main_shell.dart';

class WelcomeScreen extends StatefulWidget {
  final SacContainer container;

  const WelcomeScreen({super.key, required this.container});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _loading = false;
  List<Workspace> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  /// 최근 Workspace 목록을 로드한다.
  Future<void> _loadRecent() async {
    final list = await widget.container.workspaceService.listWorkspaces();
    if (mounted) setState(() => _recent = list);
  }

  /// Workspace 열기 후 MainShell로 이동한다.
  Future<void> _enterWorkspace(Workspace workspace) async {
    setState(() => _loading = true);
    try {
      final opened = await widget.container.workspaceService.openWorkspace(workspace.id);
      await widget.container.bindWorkspace(opened);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainShell(container: widget.container),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workspace 열기 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 기본 경로에 새 Workspace를 생성한다.
  Future<void> _createDefaultWorkspace() async {
    setState(() => _loading = true);
    try {
      final docs = await getApplicationDocumentsDirectory();
      final rootPath = p.join(docs.path, 'SAC DOCS');
      final workspace = await widget.container.workspaceService.createWorkspace(
        name: 'SAC DOCS',
        rootPath: rootPath,
      );
      await widget.container.bindWorkspace(workspace);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainShell(container: widget.container),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workspace 생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 폴더 선택으로 기존 Workspace를 연다.
  Future<void> _openExistingWorkspace() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Workspace 폴더 선택',
    );
    if (selected == null) return;

    setState(() => _loading = true);
    try {
      final workspace =
          await widget.container.workspaceService.openWorkspaceAtPath(selected);
      await widget.container.bindWorkspace(workspace);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainShell(container: widget.container),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workspace 열기 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'SAC — SVIL Archive Core',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '로컬 Markdown Workspace를 열거나 새로 만드세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _createDefaultWorkspace,
                  child: const Text('새 Workspace 만들기 (기본 경로)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _loading ? null : _openExistingWorkspace,
                  child: const Text('기존 Workspace 열기'),
                ),
                if (_loading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_recent.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('최근 Workspace', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  ..._recent.map(
                    (w) => ListTile(
                      title: Text(w.name, style: const TextStyle(fontSize: 16)),
                      subtitle: Text(
                        w.rootPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      onTap: _loading ? null : () => _enterWorkspace(w),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
