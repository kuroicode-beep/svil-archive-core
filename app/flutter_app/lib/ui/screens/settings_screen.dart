// settings_screen.dart — RC 기준 Settings 화면 (Sprint 11)

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
import '../../domain/services/release_finalization_export_service.dart';
import '../../domain/services/release_readiness_service.dart';
import '../../domain/services/verification_pass_record_service.dart';
import '../../domain/services/settings_service.dart';
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
  int _enabledToolCount = 0;
  int _disabledToolCount = 0;
  bool _loading = true;
  bool _actionInProgress = false;
  final _ollamaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _ollamaController.dispose();
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
    final tools = await widget.toolRegistryService.listTools();
    final enabled = tools.where((t) => t.enabled).length;
    if (!mounted) return;
    _ollamaController.text = settings.ollamaEndpoint;
    setState(() {
      _settings = settings;
      _localAi = localAi;
      _mcpStatus = mcp;
      _integrity = integrity;
      _readiness = readiness;
      _enabledToolCount = enabled;
      _disabledToolCount = tools.length - enabled;
      _loading = false;
    });
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
              ],
            ),
            _sectionCard(
              title: 'About',
              children: const [
                Text('SAC — SVIL Archive Core', style: TextStyle(fontSize: 16)),
                Text('Sprint 11 — RC Finalization / Release Notes', style: TextStyle(fontSize: 16)),
                Text('자동 배포·코드 서명·notarization: 범위 외', style: TextStyle(fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
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
