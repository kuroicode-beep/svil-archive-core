// settings_screen.dart — RC 기준 Settings 화면 (Sprint 11)

import 'dart:io';

import 'package:flutter/material.dart';

import '../../application/sac_theme_controller.dart';
import '../../domain/models/dashboard.dart';
import '../../domain/models/integrity_scan.dart';
import '../../domain/models/rc_finalization.dart';
import '../../domain/models/release_readiness.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/work_queue.dart';
import '../../domain/models/workspace.dart';
import '../../domain/services/build_environment_check_service.dart';
import '../../domain/services/local_ai_service.dart';
import '../../domain/services/mcp_bridge_status_service.dart';
import '../../domain/services/mcp_tool_registry_service.dart';
import '../../domain/services/release_checklist_export_service.dart';
import '../../data/services/report_consistency_service_impl.dart';
import '../../domain/models/rc_build_approval.dart';
import '../../domain/services/final_release_bundle_export_service.dart';
import '../../domain/services/rc_build_artifact_service.dart';
import '../../domain/services/rc_tag_readiness_service.dart';
import '../../domain/services/release_approval_service.dart';
import '../../domain/services/release_finalization_export_service.dart';
import '../../domain/services/release_readiness_service.dart';
import '../../domain/services/smoke_approval_service.dart';
import '../../domain/services/verification_pass_record_service.dart';
import '../../domain/models/sidecar_lifecycle.dart';
import '../../domain/services/settings_service.dart';
import '../../domain/services/sidecar_process_manager.dart';
import '../../domain/services/windows_autostart_service.dart';
import '../../application/sac_desktop_shell.dart';
import '../../domain/services/workspace_integrity_service.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  final SacThemeController themeController;
  final LocalAiService localAiService;
  final McpBridgeStatusService mcpBridgeService;
  final McpToolRegistryService toolRegistryService;
  final WorkspaceIntegrityService integrityService;
  final ReleaseReadinessService releaseReadinessService;
  final BuildEnvironmentCheckService buildEnvironmentCheckService;
  final ReleaseChecklistExportService releaseChecklistExportService;
  final VerificationPassRecordService verificationPassRecordService;
  final ReleaseFinalizationExportService releaseFinalizationExportService;
  final ReleaseApprovalService releaseApprovalService;
  final SmokeApprovalService smokeApprovalService;
  final RcBuildArtifactService rcBuildArtifactService;
  final RcTagReadinessService rcTagReadinessService;
  final FinalReleaseBundleExportService finalReleaseBundleExportService;
  final SidecarProcessManager sidecarProcessManager;
  final WindowsAutostartService windowsAutostartService;
  final SacDesktopShell desktopShell;
  final Workspace? workspace;
  final void Function(String endpoint)? onOllamaEndpointChanged;

  const SettingsScreen({
    super.key,
    required this.settingsService,
    required this.themeController,
    required this.localAiService,
    required this.mcpBridgeService,
    required this.toolRegistryService,
    required this.integrityService,
    required this.releaseReadinessService,
    required this.buildEnvironmentCheckService,
    required this.releaseChecklistExportService,
    required this.verificationPassRecordService,
    required this.releaseFinalizationExportService,
    required this.releaseApprovalService,
    required this.smokeApprovalService,
    required this.rcBuildArtifactService,
    required this.rcTagReadinessService,
    required this.finalReleaseBundleExportService,
    required this.sidecarProcessManager,
    required this.windowsAutostartService,
    required this.desktopShell,
    this.workspace,
    this.onOllamaEndpointChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings? _settings;
  LocalAiStatus? _localAi;
  McpBridgeStatus? _mcpStatus;
  IntegritySummary? _integrity;
  ReleaseReadinessSummary? _readiness;
  ReleaseApprovalSummary? _approval;
  SmokeApprovalSummary? _smokeApproval;
  List<RcBuildArtifact> _artifacts = [];
  int _enabledToolCount = 0;
  int _disabledToolCount = 0;
  SidecarLifecycleSnapshot? _sidecarSnapshot;
  WindowsAutostartStatus? _autostartStatus;
  bool _loading = true;
  bool _actionInProgress = false;
  final _ollamaController = TextEditingController();
  final _gitRepoController = TextEditingController();
  final _gitBranchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _ollamaController.dispose();
    _gitRepoController.dispose();
    _gitBranchController.dispose();
    super.dispose();
  }

  /// Settings 데이터를 다시 로드한다.
  Future<void> _refresh() async {
    setState(() => _loading = true);
    final settings = await widget.settingsService.getSettings();
    final localAi = await widget.localAiService.checkStatus();
    final mcp = await widget.mcpBridgeService.checkStatus();
    final integrity = await widget.integrityService.getLatestSummary();
    final readiness = await widget.releaseReadinessService.getLatestSummary();
    final approval = await widget.releaseApprovalService.getLatestSummary();
    final smokeApproval = await widget.smokeApprovalService.getSmokeApprovalSummary();
    final artifacts = await widget.rcBuildArtifactService.listBuildArtifacts(limit: 5);
    final tools = await widget.toolRegistryService.listTools();
    final enabled = tools.where((t) => t.enabled).length;
    final sidecarSnapshot = await widget.sidecarProcessManager.refresh();
    final autostartStatus = await widget.windowsAutostartService.getStatus(
      registeredExePath: settings.registeredAutostartExePath,
    );
    if (!mounted) return;
    _ollamaController.text = settings.ollamaEndpoint;
    _gitRepoController.text = settings.gitSync.repoUrl;
    _gitBranchController.text = settings.gitSync.branch;
    setState(() {
      _settings = settings;
      _localAi = localAi;
      _mcpStatus = mcp;
      _integrity = integrity;
      _readiness = readiness;
      _approval = approval;
      _smokeApproval = smokeApproval;
      _artifacts = artifacts;
      _enabledToolCount = enabled;
      _disabledToolCount = tools.length - enabled;
      _sidecarSnapshot = sidecarSnapshot;
      _autostartStatus = autostartStatus;
      _loading = false;
    });
  }

  /// startup/sidecar 설정을 저장한다.
  Future<void> _saveStartupSettings(AppSettings settings) async {
    await widget.settingsService.saveSettings(settings);
    await _refresh();
  }

  /// Windows autostart를 토글한다.
  Future<void> _toggleStartWithWindows(bool enabled) async {
    final settings = _settings;
    if (settings == null) return;
    setState(() => _actionInProgress = true);
    try {
      if (enabled) {
        final exe = Platform.resolvedExecutable;
        await widget.windowsAutostartService.enable(exePath: exe);
        await _saveStartupSettings(
          settings.copyWith(startWithWindows: true, registeredAutostartExePath: exe),
        );
      } else {
        await widget.windowsAutostartService.disable();
        await _saveStartupSettings(
          settings.copyWith(startWithWindows: false, clearRegisteredAutostartExePath: true),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  /// Ollama endpoint를 저장한다.
  Future<void> _saveOllamaEndpoint() async {
    final current = _settings;
    if (current == null) return;
    final endpoint = _ollamaController.text.trim();
    if (endpoint.isEmpty) return;
    await widget.settingsService.saveSettings(current.copyWith(ollamaEndpoint: endpoint));
    widget.onOllamaEndpointChanged?.call(endpoint);
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ollama endpoint 저장됨')),
    );
  }

  /// Git Sync 설정을 저장한다.
  Future<void> _saveGitSync(GitSyncSettings gitSync) async {
    final current = _settings;
    if (current == null) return;
    await widget.settingsService.saveSettings(current.copyWith(gitSync: gitSync));
    await _refresh();
  }

  /// 다운로드 감시 설정을 저장한다.
  Future<void> _saveDownloads(DownloadWatcherSettings downloads) async {
    final current = _settings;
    if (current == null) return;
    await widget.settingsService.saveSettings(current.copyWith(downloads: downloads));
    await _refresh();
  }

  /// RC readiness를 재평가한다.
  Future<void> _evaluateReadiness() async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final summary = await widget.releaseReadinessService.evaluate();
      if (!mounted) return;
      setState(() => _readiness = summary);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            summary.rcStatusLabel,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  /// 빌드 환경 점검을 실행한다.
  Future<void> _runBuildChecks() async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final checks = await widget.buildEnvironmentCheckService.runChecks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('빌드 환경 점검 ${checks.length}항목 완료')),
      );
      await _evaluateReadiness();
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  /// RC tag readiness 체크를 실행한다.
  Future<void> _runTagReadiness() async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final summary = await widget.rcTagReadinessService.runRcTagReadinessChecks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tag readiness ${summary.items.where((i) => i.passed).length}/${summary.items.length} pass')),
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  /// Final release bundle을 export한다.
  Future<void> _exportFinalBundle() async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final result = await widget.finalReleaseBundleExportService.exportFinalReleaseBundle();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Final bundle 저장: ${result.relativePath}')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  /// Sprint 11 Markdown export를 실행한다.
  Future<void> _exportFinalization(String kind) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final ReleaseMarkdownExportResult result;
      switch (kind) {
        case 'notes':
          result = await widget.releaseFinalizationExportService.exportReleaseNotes();
        case 'issues':
          result = await widget.releaseFinalizationExportService.exportKnownIssues();
        case 'tag':
          result = await widget.releaseFinalizationExportService.exportTagReadinessChecklist();
        default:
          return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export 저장: ${result.relativePath}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  /// RC 체크리스트를 export한다.
  Future<void> _exportChecklist() async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final result = await widget.releaseChecklistExportService.exportToFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export 저장: ${result.relativePath}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _settings == null || _localAi == null || _mcpStatus == null || _integrity == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final settings = _settings!;
    final localAi = _localAi!;
    final mcp = _mcpStatus!;
    final integrity = _integrity!;
    final readiness = _readiness;
    final workspace = widget.workspace;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('설정', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'RC / Smoke / Packaging Readiness 기준 정리',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Workspace',
              children: [
                Text('이름: ${workspace?.name ?? '(미선택)'}', style: const TextStyle(fontSize: 16)),
                Text('경로: ${workspace?.rootPath ?? '(미선택)'}', style: const TextStyle(fontSize: 16)),
                Text('workspace_id: ${settings.workspaceId}', style: const TextStyle(fontSize: 16)),
              ],
            ),
            _sectionCard(
              title: 'Appearance',
              children: [
                SwitchListTile(
                  title: const Text('고대비 모드', style: TextStyle(fontSize: 16)),
                  value: widget.themeController.highContrastEnabled,
                  onChanged: widget.themeController.toggleHighContrast,
                ),
                const Text('최소 폰트 16px / 터치 타겟 50px 이상', style: TextStyle(fontSize: 16)),
              ],
            ),
            _sectionCard(
              title: 'Local AI',
              children: [
                Text('상태: ${localAi.label}', style: const TextStyle(fontSize: 16)),
                Text('endpoint: ${localAi.endpoint ?? settings.ollamaEndpoint}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _ollamaController,
                  decoration: const InputDecoration(
                    labelText: 'Ollama endpoint',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveOllamaEndpoint,
                    child: const Text('endpoint 저장'),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('외부 API: 기본 OFF (자동 호출 없음)', style: TextStyle(fontSize: 16)),
              ],
            ),
            _sectionCard(
              title: 'MCP',
              children: [
                Text('bridge: ${mcp.label}', style: const TextStyle(fontSize: 16)),
                Text('local-only: ${mcp.localOnly}', style: const TextStyle(fontSize: 16)),
                Text('remote exposure: ${mcp.remoteExposureEnabled}', style: const TextStyle(fontSize: 16)),
                Text('enabled tools: $_enabledToolCount / disabled: $_disabledToolCount', style: const TextStyle(fontSize: 16)),
                Text('MCP enabled setting: ${settings.mcpEnabled}', style: const TextStyle(fontSize: 16)),
              ],
            ),
            _sectionCard(
              title: 'MCP / Startup',
              children: [
                if (_sidecarSnapshot != null) ...[
                  Text(
                    sidecarLifecycleStatusLabel(_sidecarSnapshot!.status),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'packaged path: ${_sidecarSnapshot!.maskedSidecarPath ?? 'n/a'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_sidecarSnapshot!.lastStartError != null)
                    Text(
                      'last error: ${_sidecarSnapshot!.lastStartError}',
                      style: const TextStyle(fontSize: 16),
                    ),
                ],
                SwitchListTile(
                  title: const Text('시작 시 MCP sidecar 자동 시작', style: TextStyle(fontSize: 16)),
                  value: settings.autoStartSidecar,
                  onChanged: _actionInProgress
                      ? null
                      : (value) => _saveStartupSettings(settings.copyWith(autoStartSidecar: value)),
                ),
                SwitchListTile(
                  title: const Text('창 닫을 때 트레이에 유지', style: TextStyle(fontSize: 16)),
                  value: settings.closeToTray,
                  onChanged: _actionInProgress
                      ? null
                      : (value) => _saveStartupSettings(settings.copyWith(closeToTray: value)),
                ),
                if (Platform.isWindows)
                  SwitchListTile(
                    title: const Text('Windows 시작 시 SAC 자동 실행', style: TextStyle(fontSize: 16)),
                    value: settings.startWithWindows,
                    onChanged: _actionInProgress ? null : _toggleStartWithWindows,
                  ),
                if (_autostartStatus?.pathMismatch == true)
                  const Text(
                    'autostart 경로 불일치 — Settings에서 다시 등록하세요',
                    style: TextStyle(fontSize: 16, color: Colors.orange),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _actionInProgress
                              ? null
                              : () async {
                                  setState(() => _actionInProgress = true);
                                  await widget.sidecarProcessManager.restart();
                                  await _refresh();
                                  if (mounted) setState(() => _actionInProgress = false);
                                },
                          child: const Text('sidecar 재시작'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _actionInProgress
                              ? null
                              : () async {
                                  setState(() => _actionInProgress = true);
                                  await widget.sidecarProcessManager.stop();
                                  await _refresh();
                                  if (mounted) setState(() => _actionInProgress = false);
                                },
                          child: const Text('sidecar 중지'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _actionInProgress
                        ? null
                        : () => widget.desktopShell.quitCompletely(),
                    child: const Text('SAC 완전 종료'),
                  ),
                ),
              ],
            ),
            _gitSyncSection(settings),
            _downloadsSection(settings),
            _sectionCard(
              title: 'Privacy',
              children: const [
                Text('외부 전송: 비활성화', style: TextStyle(fontSize: 16)),
                Text('개인 데이터: 수동 승인만', style: TextStyle(fontSize: 16)),
                Text('export: approved / active only', style: TextStyle(fontSize: 16)),
                Text('MCP write/destructive: queue 승인 필수', style: TextStyle(fontSize: 16)),
              ],
            ),
            _sectionCard(
              title: 'Integrity',
              children: [
                Text('orphan Markdown: ${integrity.openOrphanCount}건', style: const TextStyle(fontSize: 16)),
                Text('stale DB row: ${integrity.openStaleDbCount}건', style: const TextStyle(fontSize: 16)),
                Text('conflict: ${integrity.openConflictCount}건', style: const TextStyle(fontSize: 16)),
              ],
            ),
            _sectionCard(
              title: 'Release',
              children: [
                Text(
                  'RC 기준 커밋: ${kRcVerificationSprintCommit.isEmpty ? 'n/a' : kRcVerificationSprintCommit}',
                  style: const TextStyle(fontSize: 16),
                ),
                if (_approval != null) ...[
                  Text(
                    _approval!.statusLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'approval status: ${_approval!.status.name}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
                if (_smokeApproval != null) ...[
                  Text(
                    'smoke macOS: ${_smokeApproval!.macStatus?.name ?? 'pending'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'smoke Windows: ${_smokeApproval!.windowsStatus?.name ?? 'pending'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
                Text(
                  'build artifacts: ${_artifacts.length}',
                  style: const TextStyle(fontSize: 16),
                ),
                if (readiness != null) ...[
                  Text(
                    readiness.rcStatusLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'RC 상태: ${readiness.rcFinalizationStatus.name}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'pass ${readiness.passCount} / warn ${readiness.warnCount} / fail ${readiness.failCount}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'macOS smoke: ${_smokeLabel(readiness, 'macOS smoke')}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Windows smoke: ${_smokeLabel(readiness, 'Windows smoke')}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ] else
                  const Text('RC 평가 기록 없음 — 아래 버튼으로 실행', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                FutureBuilder(
                  future: Future.wait([
                    widget.verificationPassRecordService.getLatestForType('analyze'),
                    widget.verificationPassRecordService.getLatestForType('test'),
                    widget.verificationPassRecordService.getLatestForType('sidecar_build'),
                  ]),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Text('검증 기록 로딩...', style: TextStyle(fontSize: 16));
                    }
                    final records = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'analyze commit: ${records[0]?.verifiedSprintCommit ?? '없음'}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          'test commit: ${records[1]?.verifiedSprintCommit ?? '없음'} (${records[1]?.testCount ?? '-'} tests)',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          'sidecar commit: ${records[2]?.verifiedSprintCommit ?? '없음'}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _actionInProgress ? null : _evaluateReadiness,
                    child: Text(_actionInProgress ? '처리 중...' : 'RC readiness 평가'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _actionInProgress ? null : _runBuildChecks,
                    child: const Text('빌드 환경 점검'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _actionInProgress ? null : _exportChecklist,
                    child: const Text('Release checklist export'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _actionInProgress ? null : () => _exportFinalization('notes'),
                    child: const Text('Release notes export'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _actionInProgress ? null : () => _exportFinalization('issues'),
                    child: const Text('Known issues export'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _actionInProgress ? null : () => _exportFinalization('tag'),
                    child: const Text('v0.1 RC tag readiness checklist'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _actionInProgress ? null : _runTagReadiness,
                    child: const Text('Run RC tag readiness checks'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _actionInProgress ? null : _exportFinalBundle,
                    child: const Text('Final release bundle export'),
                  ),
                ),
              ],
            ),
            _sectionCard(
              title: 'About',
              children: const [
                Text('SAC — SVIL Archive Core', style: TextStyle(fontSize: 16)),
                Text('Sprint 12 — RC Build Approval / Tag Readiness', style: TextStyle(fontSize: 16)),
                Text('자동 배포·코드 서명·notarization: 범위 외', style: TextStyle(fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Git Sync 설정 섹션 (Sprint 16).
  Widget _gitSyncSection(AppSettings settings) {
    final git = settings.gitSync;
    return _sectionCard(
      title: 'Git Sync',
      children: [
        const Text(
          'SAC DOCS가 Git working tree일 때 동기화합니다. 토큰/비밀번호는 저장하지 않으며 '
          'OS git credential을 사용합니다. 자동 commit/push는 기본 OFF입니다.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Git Sync 사용', style: TextStyle(fontSize: 16)),
          value: git.enabled,
          onChanged: _actionInProgress
              ? null
              : (v) => _saveGitSync(git.copyWith(enabled: v)),
        ),
        TextField(
          controller: _gitRepoController,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            labelText: 'Git repo URL (https:// 또는 git@...)',
            labelStyle: TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _gitBranchController,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            labelText: 'branch (예: main)',
            labelStyle: TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 8),
        Text('remote: ${git.remoteName}', style: const TextStyle(fontSize: 16)),
        Row(
          children: [
            Expanded(
              child: Text('sync interval: ${git.syncIntervalMinutes}분',
                  style: const TextStyle(fontSize: 16)),
            ),
            IconButton(
              iconSize: 28,
              onPressed: _actionInProgress || git.syncIntervalMinutes <= 5
                  ? null
                  : () => _saveGitSync(
                      git.copyWith(syncIntervalMinutes: git.syncIntervalMinutes - 5)),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              iconSize: 28,
              onPressed: _actionInProgress
                  ? null
                  : () => _saveGitSync(
                      git.copyWith(syncIntervalMinutes: git.syncIntervalMinutes + 5)),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        SwitchListTile(
          title: const Text('자동 commit (기본 OFF)', style: TextStyle(fontSize: 16)),
          value: git.autoCommit,
          onChanged: _actionInProgress
              ? null
              : (v) => _saveGitSync(git.copyWith(autoCommit: v)),
        ),
        SwitchListTile(
          title: const Text('자동 push (기본 OFF)', style: TextStyle(fontSize: 16)),
          value: git.autoPush,
          onChanged: _actionInProgress
              ? null
              : (v) => _saveGitSync(git.copyWith(autoPush: v)),
        ),
        SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _actionInProgress
                ? null
                : () => _saveGitSync(git.copyWith(
                      repoUrl: _gitRepoController.text.trim(),
                      branch: _gitBranchController.text.trim().isEmpty
                          ? git.branch
                          : _gitBranchController.text.trim(),
                    )),
            child: const Text('Git 설정 저장'),
          ),
        ),
      ],
    );
  }

  /// 다운로드 감시 설정 섹션 (Sprint 16).
  Widget _downloadsSection(AppSettings settings) {
    final dl = settings.downloads;
    return _sectionCard(
      title: '다운로드 감시',
      children: [
        const Text(
          '다운로드 폴더에서 ai_sync_* Markdown을 감지해 Import Queue에 등록합니다. '
          '원본은 삭제하지 않으며 자동 import는 기본 OFF입니다.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('다운로드 폴더 감시 사용 (기본 OFF)', style: TextStyle(fontSize: 16)),
          value: dl.enabled,
          onChanged: _actionInProgress
              ? null
              : (v) => _saveDownloads(dl.copyWith(enabled: v)),
        ),
        SwitchListTile(
          title: const Text('자동 import (기본 OFF)', style: TextStyle(fontSize: 16)),
          value: dl.autoImport,
          onChanged: _actionInProgress
              ? null
              : (v) => _saveDownloads(dl.copyWith(autoImport: v)),
        ),
        SwitchListTile(
          title: const Text('하위 폴더 포함', style: TextStyle(fontSize: 16)),
          value: dl.includeSubfolders,
          onChanged: _actionInProgress
              ? null
              : (v) => _saveDownloads(dl.copyWith(includeSubfolders: v)),
        ),
        Text('감시 폴더: ${dl.folderPath.isEmpty ? "기본 Downloads" : dl.folderPath}',
            style: const TextStyle(fontSize: 16)),
        Text('scan interval: ${dl.scanIntervalMinutes}분', style: const TextStyle(fontSize: 16)),
        Text('prefix: ${dl.prefixes.join(", ")}', style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  /// 섹션 카드를 구성한다.
  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  /// readiness 항목에서 smoke 라벨을 찾는다.
  String _smokeLabel(ReleaseReadinessSummary readiness, String label) {
    final item = readiness.items.where((i) => i.label == label).toList();
    if (item.isEmpty) return 'unknown';
    return item.first.status.name;
  }
}
