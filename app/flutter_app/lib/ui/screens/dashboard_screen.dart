// dashboard_screen.dart — SAC 대시보드 화면 (Sprint 6)

import 'package:flutter/material.dart';

import '../../domain/models/dashboard.dart';
import '../../domain/services/dashboard_service.dart';
import '../../domain/services/llm_self_info_export_service.dart';
import '../../domain/services/local_ai_service.dart';
import '../../domain/services/privacy_service.dart';
import '../widgets/ai_collaboration_status_panel.dart';
import '../widgets/privacy_status_panel.dart';

class DashboardScreen extends StatefulWidget {
  final DashboardService dashboardService;
  final PrivacyService privacyService;
  final LocalAiService localAiService;
  final LlmSelfInfoExportService exportService;
  final void Function(DashboardNavTarget target)? onNavigate;

  const DashboardScreen({
    super.key,
    required this.dashboardService,
    required this.privacyService,
    required this.localAiService,
    required this.exportService,
    this.onNavigate,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum DashboardNavTarget { personalArchive, extractionQueue, search, privacy }

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardSummary? _summary;
  PrivacySummary? _privacy;
  LocalAiStatus? _localAi;
  bool _loading = true;
  String? _exportPreview;
  bool _exportInProgress = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// 대시보드 데이터를 다시 로드한다.
  Future<void> _refresh() async {
    setState(() => _loading = true);
    final summary = await widget.dashboardService.getDashboardSummary();
    final privacy = await widget.privacyService.getPrivacySummary();
    final localAi = await widget.localAiService.checkStatus();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _privacy = privacy;
      _localAi = localAi;
      _loading = false;
    });
  }

  /// LLM 자기정보 문서 preview를 생성한다.
  Future<void> _buildExportPreview() async {
    if (_exportInProgress) return;
    setState(() => _exportInProgress = true);
    try {
      final result = await widget.exportService.buildPreview();
      if (!mounted) return;
      setState(() => _exportPreview = result.previewMarkdown);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview 생성 완료 (${result.includedItemCount}건 포함)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview 생성 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportInProgress = false);
    }
  }

  /// LLM 자기정보 문서를 파일로 export한다.
  Future<void> _exportToFile() async {
    if (_exportInProgress) return;
    setState(() => _exportInProgress = true);
    try {
      final result = await widget.exportService.exportToFile();
      if (!mounted) return;
      setState(() => _exportPreview = result.previewMarkdown);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export 저장: ${result.relativePath}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportInProgress = false);
    }
  }

  /// Critical 알림 섹션을 구성한다.
  Widget _buildCriticalSection(CriticalAlertSummary alerts) {
    if (!alerts.hasCritical) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Critical 없음', style: TextStyle(fontSize: 16)),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Critical / 충돌 알림',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (alerts.syncConflictCount > 0)
              Text('상태: sync conflict ${alerts.syncConflictCount}건', style: const TextStyle(fontSize: 16)),
            if (alerts.pendingExtractionCount > 0)
              Text('상태: 승인 대기 ${alerts.pendingExtractionCount}건', style: const TextStyle(fontSize: 16)),
            if (alerts.privacyWarningCount > 0)
              Text('상태: privacy warning ${alerts.privacyWarningCount}건', style: const TextStyle(fontSize: 16)),
            if (alerts.failedIndexingCount > 0)
              Text('상태: indexing backlog ${alerts.failedIndexingCount}건', style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _summary == null || _privacy == null || _localAi == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final summary = _summary!;
    final privacy = _privacy!;
    final localAi = _localAi!;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('대시보드', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            AiCollaborationStatusPanel(summary: summary.aiCollaboration),
            const SizedBox(height: 12),
            _buildCriticalSection(summary.criticalAlerts),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('로컬 AI 상태', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('상태: ${localAi.label}', style: const TextStyle(fontSize: 16)),
                    if (localAi.endpoint != null)
                      Text('엔드포인트: ${localAi.endpoint}', style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            PrivacyStatusPanel(summary: privacy),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('통합 검색 / 바로가기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => widget.onNavigate?.call(DashboardNavTarget.search),
                        child: const Text('통합 검색 열기'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => widget.onNavigate?.call(DashboardNavTarget.personalArchive),
                        child: const Text('개인 아카이브 열기'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => widget.onNavigate?.call(DashboardNavTarget.extractionQueue),
                        child: const Text('추출 대기열 열기'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _exportInProgress ? null : _buildExportPreview,
                        child: Text(_exportInProgress ? '처리 중...' : 'LLM용 자기정보 문서 Preview'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _exportInProgress ? null : _exportToFile,
                        child: const Text('LLM용 자기정보 문서 Export'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('최근 키워드 / 태그', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (summary.recentTags.isEmpty)
                      const Text('(없음)', style: TextStyle(fontSize: 16))
                    else
                      Wrap(
                        spacing: 8,
                        children: summary.recentTags
                            .map((tag) => Chip(label: Text(tag, style: const TextStyle(fontSize: 14))))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('최근 활동', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (summary.recentActivities.isEmpty)
                      const Text('(없음)', style: TextStyle(fontSize: 16))
                    else
                      ...summary.recentActivities.map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${item.action} · ${item.targetType} · ${item.targetId ?? '-'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('작업큐 요약', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('문서: ${summary.documentCount}건', style: const TextStyle(fontSize: 16)),
                    Text('휴지통: ${summary.trashCount}건', style: const TextStyle(fontSize: 16)),
                    Text(
                      '승인 대기 추출: ${summary.criticalAlerts.pendingExtractionCount}건',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            if (_exportPreview != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LLM Self Info Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 240,
                        child: SingleChildScrollView(
                          child: Text(_exportPreview!, style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
