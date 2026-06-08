// integrity_screen.dart — workspace 무결성 / smoke test 화면 (Sprint 9–10)

import 'package:flutter/material.dart';

import '../../domain/models/integrity_scan.dart';
import '../../domain/models/smoke_test_record.dart'
    show
        SmokeTestRecord,
        SmokeTestStatus,
        kDefaultMacOsSmokeChecklist,
        kDefaultWindowsSmokeChecklist;
import '../../domain/services/report_consistency_service.dart';
import '../../domain/services/smoke_test_record_service.dart';
import '../../domain/services/workspace_integrity_service.dart';

class IntegrityScreen extends StatefulWidget {
  final WorkspaceIntegrityService integrityService;
  final SmokeTestRecordService smokeTestRecordService;
  final ReportConsistencyService reportConsistencyService;
  final VoidCallback? onOpenImport;

  const IntegrityScreen({
    super.key,
    required this.integrityService,
    required this.smokeTestRecordService,
    required this.reportConsistencyService,
    this.onOpenImport,
  });

  @override
  State<IntegrityScreen> createState() => _IntegrityScreenState();
}

class _IntegrityScreenState extends State<IntegrityScreen> {
  IntegritySummary? _summary;
  List<IntegrityScanItem> _openItems = [];
  SmokeTestRecord? _macSmoke;
  SmokeTestRecord? _winSmoke;
  bool _reportConsistent = true;
  bool _loading = true;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// 무결성 요약을 다시 로드한다.
  Future<void> _refresh() async {
    setState(() => _loading = true);
    final summary = await widget.integrityService.getLatestSummary();
    final items = await widget.integrityService.listOpenItems();
    final macSmoke = await widget.smokeTestRecordService.getLatestForPlatform('macOS');
    final winSmoke = await widget.smokeTestRecordService.getLatestForPlatform('Windows');
    final report = await widget.reportConsistencyService.checkReports();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _openItems = items;
      _macSmoke = macSmoke;
      _winSmoke = winSmoke;
      _reportConsistent = report.isConsistent;
      _loading = false;
    });
  }

  /// 무결성 스캔을 실행한다.
  Future<void> _runScan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      await widget.integrityService.runScan();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('스캔 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// 플랫폼 smoke 기록을 생성한다.
  Future<void> _createSmokeRecord(String platform, List<String> checklist) async {
    await widget.smokeTestRecordService.createRecord(
      platform: platform,
      checklistName: 'SAC $platform Smoke',
      status: SmokeTestStatus.pending,
      notes: 'Sprint 10 checklist — ${checklist.length} items',
    );
    await _refresh();
  }

  /// smoke 기록 상태를 갱신한다.
  Future<void> _updateSmokeStatus(SmokeTestRecord? record, SmokeTestStatus status) async {
    if (record == null) return;
    await widget.smokeTestRecordService.updateRecord(id: record.id, status: status);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _summary == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final summary = _summary!;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '무결성 / 복구',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '자동 삭제·자동 복구 없음 — 탐지와 승인 기반 복구만 허용',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _scanning ? null : _runScan,
                child: Text(_scanning ? '스캔 중...' : '무결성 스캔 실행'),
              ),
            ),
            if (widget.onOpenImport != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: widget.onOpenImport,
                  child: const Text('Orphan Markdown 가져오기'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('무결성 요약', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('orphan Markdown: ${summary.openOrphanCount}건', style: const TextStyle(fontSize: 16)),
                    Text('stale DB row: ${summary.openStaleDbCount}건', style: const TextStyle(fontSize: 16)),
                    Text('conflict: ${summary.openConflictCount}건', style: const TextStyle(fontSize: 16)),
                    Text('warning: ${summary.openWarningCount}건', style: const TextStyle(fontSize: 16)),
                    Text(
                      '보고서 정합성: ${_reportConsistent ? '일치' : '불일치'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSmokeSection(
              title: 'macOS Smoke',
              record: _macSmoke,
              checklist: kDefaultMacOsSmokeChecklist,
              onCreate: () => _createSmokeRecord('macOS', kDefaultMacOsSmokeChecklist),
            ),
            const SizedBox(height: 12),
            _buildSmokeSection(
              title: 'Windows Smoke',
              record: _winSmoke,
              checklist: kDefaultWindowsSmokeChecklist,
              onCreate: () => _createSmokeRecord('Windows', kDefaultWindowsSmokeChecklist),
            ),
            const SizedBox(height: 12),
            if (_openItems.isEmpty)
              const Text('열린 이슈 없음', style: TextStyle(fontSize: 16))
            else
              ..._openItems.map(
                (item) => Card(
                  child: ListTile(
                    title: Text('${item.itemType.name} · ${item.severity.name}', style: const TextStyle(fontSize: 16)),
                    subtitle: Text(
                      '${item.targetPath ?? item.documentId ?? '-'} · ${item.reason}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// smoke test 섹션을 구성한다.
  Widget _buildSmokeSection({
    required String title,
    required SmokeTestRecord? record,
    required List<String> checklist,
    required VoidCallback onCreate,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '상태: ${record?.status.name ?? '기록 없음'}',
              style: const TextStyle(fontSize: 16),
            ),
            if (record?.notes != null)
              Text('notes: ${record!.notes}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('checklist (${checklist.length}항목)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ...checklist.map((item) => Text('• $item', style: const TextStyle(fontSize: 16))),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: onCreate,
                child: Text('$title 기록 생성'),
              ),
            ),
            if (record != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _updateSmokeStatus(record, SmokeTestStatus.passed),
                        child: const Text('PASS'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => _updateSmokeStatus(record, SmokeTestStatus.failed),
                        child: const Text('FAIL'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => _updateSmokeStatus(record, SmokeTestStatus.skipped),
                        child: const Text('SKIP'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
