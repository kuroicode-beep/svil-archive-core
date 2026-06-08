// work_queue_panel.dart — 작업큐 / 티켓 / 실행 화면 (Sprint 8)

import 'package:flutter/material.dart';

import '../../domain/models/execution_recovery.dart';
import '../../domain/models/ticket_execution.dart';
import '../../domain/models/work_queue.dart';
import '../../domain/services/execution_recovery_service.dart';
import '../../domain/services/queue_execution_service.dart';
import '../../domain/services/release_readiness_service.dart';
import '../../domain/services/work_queue_service.dart';

class WorkQueuePanel extends StatefulWidget {
  final WorkQueueService workQueueService;
  final QueueExecutionService queueExecutionService;
  final ExecutionRecoveryService executionRecoveryService;
  final ReleaseReadinessService? releaseReadinessService;

  const WorkQueuePanel({
    super.key,
    required this.workQueueService,
    required this.queueExecutionService,
    required this.executionRecoveryService,
    this.releaseReadinessService,
  });

  @override
  State<WorkQueuePanel> createState() => _WorkQueuePanelState();
}

class _WorkQueuePanelState extends State<WorkQueuePanel> {
  WorkQueueSummary? _summary;
  List<WorkQueueTicket> _pending = [];
  List<WorkQueueTicket> _all = [];
  WorkQueueTicket? _selected;
  bool _loading = true;
  String? _actionInProgress;
  DryRunPreview? _dryRunPreview;
  RecoveryAssessment? _recoveryAssessment;
  List<TicketExecutionLog> _executionLogs = [];
  int _releaseBlockingCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// 작업큐 데이터를 다시 로드한다.
  Future<void> _refresh() async {
    setState(() => _loading = true);
    final summary = await widget.workQueueService.getSummary();
    final pending = await widget.workQueueService.listPendingTickets();
    final all = await widget.workQueueService.listAllTickets();
    final readiness = await widget.releaseReadinessService?.getLatestSummary();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _pending = pending;
      _all = all;
      _releaseBlockingCount = readiness?.failCount ?? 0;
      _loading = false;
    });
  }

  /// 티켓을 승인한다.
  Future<void> _approve(String id) async {
    if (_actionInProgress != null) return;
    setState(() => _actionInProgress = id);
    try {
      await widget.workQueueService.approveTicket(id);
      if (!mounted) return;
      setState(() => _selected = null);
      await _refresh();
    } finally {
      if (mounted) setState(() => _actionInProgress = null);
    }
  }

  /// 선택 티켓의 실행 로그를 로드한다.
  Future<void> _loadExecutionLogs(String ticketId) async {
    final logs = await widget.queueExecutionService.listExecutionLogs(ticketId);
    if (!mounted) return;
    setState(() => _executionLogs = logs);
  }

  /// 복구 가능 여부를 평가한다.
  Future<void> _assessRecovery(String id) async {
    final assessment = await widget.executionRecoveryService.assessTicket(id);
    if (!mounted) return;
    setState(() => _recoveryAssessment = assessment);
  }

  /// 복구 preview를 생성한다.
  Future<void> _recoveryPreview(String id) async {
    if (_actionInProgress != null) return;
    setState(() => _actionInProgress = id);
    try {
      final preview = await widget.executionRecoveryService.createRecoveryPreview(id);
      if (!mounted) return;
      setState(() => _dryRunPreview = preview);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('복구 preview 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = null);
    }
  }

  /// 복구 티켓을 생성한다.
  Future<void> _createRecoveryTicket(String id) async {
    if (_actionInProgress != null) return;
    setState(() => _actionInProgress = id);
    try {
      final recovery = await widget.executionRecoveryService.createRecoveryTicket(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('복구 티켓 생성: ${recovery.id}')),
      );
      await _refresh();
      setState(() => _selected = recovery);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('복구 티켓 생성 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = null);
    }
  }

  /// dry-run preview를 생성한다.
  Future<void> _dryRun(String id) async {
    if (_actionInProgress != null) return;
    setState(() => _actionInProgress = id);
    try {
      final preview = await widget.queueExecutionService.createDryRunPreview(id);
      if (!mounted) return;
      setState(() => _dryRunPreview = preview);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dry-run 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = null);
    }
  }

  /// 승인된 티켓을 실행한다.
  Future<void> _execute(WorkQueueTicket ticket) async {
    if (_actionInProgress != null) return;
    if (ticket.permissionLevel == PermissionLevel.destructive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('파괴적 작업 확인', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: const Text(
            '이 작업은 문서를 휴지통으로 이동합니다. 영구 삭제가 아닙니다. 계속하시겠습니까?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('휴지통 이동 실행'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _actionInProgress = ticket.id);
    try {
      final result = await widget.queueExecutionService.executeApprovedTicket(ticket.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('실행 결과: ${result.status.name}')),
      );
      await _refresh();
      await _loadExecutionLogs(ticket.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('실행 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = null);
    }
  }

  /// 티켓을 취소한다.
  Future<void> _cancel(String id) async {
    if (_actionInProgress != null) return;
    setState(() => _actionInProgress = id);
    try {
      await widget.workQueueService.cancelTicket(id);
      if (!mounted) return;
      setState(() {
        _selected = null;
        _dryRunPreview = null;
      });
      await _refresh();
    } finally {
      if (mounted) setState(() => _actionInProgress = null);
    }
  }

  /// 티켓을 거절한다.
  Future<void> _reject(String id) async {
    if (_actionInProgress != null) return;
    setState(() => _actionInProgress = id);
    try {
      await widget.workQueueService.rejectTicket(id, '사용자 거절');
      if (!mounted) return;
      setState(() => _selected = null);
      await _refresh();
    } finally {
      if (mounted) setState(() => _actionInProgress = null);
    }
  }

  /// 티켓 상태 라벨을 반환한다.
  String _statusLabel(WorkQueueTicketStatus status) {
    switch (status) {
      case WorkQueueTicketStatus.pending:
        return '상태: 승인 대기';
      case WorkQueueTicketStatus.approved:
        return '상태: 승인됨';
      case WorkQueueTicketStatus.running:
        return '상태: 실행 중';
      case WorkQueueTicketStatus.completed:
        return '상태: 완료';
      case WorkQueueTicketStatus.blocked:
        return '상태: 차단됨';
      case WorkQueueTicketStatus.conflict:
        return '상태: 충돌';
      case WorkQueueTicketStatus.rejected:
        return '상태: 거절됨';
      case WorkQueueTicketStatus.failed:
        return '상태: 실패';
      case WorkQueueTicketStatus.cancelled:
        return '상태: 취소됨';
    }
  }

  /// permission level 라벨을 반환한다.
  String _permissionLabel(PermissionLevel level) {
    switch (level) {
      case PermissionLevel.read:
        return '읽기';
      case PermissionLevel.write:
        return '쓰기';
      case PermissionLevel.destructive:
        return '파괴적 작업';
      case PermissionLevel.personal:
        return '개인정보';
      case PermissionLevel.admin:
        return '관리자';
    }
  }

  /// 요약 카드를 구성한다.
  Widget _buildSummaryCard(WorkQueueSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('작업큐 요약', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('상태: 승인 대기 ${summary.pendingCount}건', style: const TextStyle(fontSize: 16)),
            Text('상태: 충돌 ${summary.conflictCount}건', style: const TextStyle(fontSize: 16)),
            Text('상태: 차단 ${summary.blockedCount}건', style: const TextStyle(fontSize: 16)),
            Text('상태: 실패 ${summary.failedCount}건', style: const TextStyle(fontSize: 16)),
            Text('상태: 승인됨 ${summary.approvedCount}건', style: const TextStyle(fontSize: 16)),
            Text('상태: 실행 중 ${summary.runningCount}건', style: const TextStyle(fontSize: 16)),
            Text('상태: 완료 ${summary.completedCount}건', style: const TextStyle(fontSize: 16)),
            Text('RC 차단 항목: $_releaseBlockingCount건', style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  /// risk level 라벨을 반환한다.
  String _riskLabel(PermissionLevel level) {
    if (level == PermissionLevel.destructive) return '위험도: 파괴적 (휴지통 이동)';
    if (level == PermissionLevel.write) return '위험도: 중간 (쓰기)';
    return '위험도: 낮음';
  }

  /// 티켓 상세 패널을 구성한다.
  Widget _buildDetailPanel(WorkQueueTicket ticket) {
    final isDestructive = ticket.permissionLevel == PermissionLevel.destructive;
    final canApprove = ticket.status == WorkQueueTicketStatus.pending;
    final canExecute = ticket.status == WorkQueueTicketStatus.approved;
    final canCancel = ticket.status == WorkQueueTicketStatus.pending ||
        ticket.status == WorkQueueTicketStatus.approved;
    final canRecover = ticket.status == WorkQueueTicketStatus.failed ||
        ticket.status == WorkQueueTicketStatus.blocked ||
        ticket.status == WorkQueueTicketStatus.conflict;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('티켓 상세', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('actor: ${ticket.actor}', style: const TextStyle(fontSize: 16)),
            Text('action: ${ticket.requestedAction}', style: const TextStyle(fontSize: 16)),
            Text('권한: ${_permissionLabel(ticket.permissionLevel)}', style: const TextStyle(fontSize: 16)),
            Text(_statusLabel(ticket.status), style: const TextStyle(fontSize: 16)),
            if (ticket.isRecoveryTicket)
              const Text('복구 티켓', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (ticket.sourceTicketId != null)
              Text('source ticket: ${ticket.sourceTicketId}', style: const TextStyle(fontSize: 16)),
            Text(_riskLabel(ticket.permissionLevel), style: const TextStyle(fontSize: 16)),
            Text(
              'dry-run: ${canExecute ? '가능' : '불가'} · 실행: ${canExecute ? '가능' : '불가'}',
              style: const TextStyle(fontSize: 16),
            ),
            if (ticket.targetPath != null)
              Text('경로: ${ticket.targetPath}', style: const TextStyle(fontSize: 16)),
            if (ticket.reason != null)
              Text('사유: ${ticket.reason}', style: const TextStyle(fontSize: 16)),
            Text(
              '생성: ${ticket.createdAt.toLocal()}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (canApprove) ...[
              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _actionInProgress == ticket.id ? null : () => _approve(ticket.id),
                  child: Text(isDestructive ? '파괴적 작업 승인' : '승인'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _actionInProgress == ticket.id ? null : () => _reject(ticket.id),
                  child: Text(isDestructive ? '파괴적 작업 거절' : '거절'),
                ),
              ),
            ],
            if (canExecute) ...[
              SizedBox(
                height: 50,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _actionInProgress == ticket.id ? null : () => _dryRun(ticket.id),
                  child: const Text('Dry-run 보기'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _actionInProgress == ticket.id ? null : () => _execute(ticket),
                  child: Text(isDestructive ? '휴지통 이동 실행' : '실행'),
                ),
              ),
            ],
            if (canCancel) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _actionInProgress == ticket.id ? null : () => _cancel(ticket.id),
                  child: const Text('취소'),
                ),
              ),
            ],
            if (canRecover) ...[
              const SizedBox(height: 12),
              const Text('실행 복구', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _actionInProgress == ticket.id ? null : () => _assessRecovery(ticket.id),
                  child: const Text('복구 가능 여부 확인'),
                ),
              ),
              if (_recoveryAssessment?.ticketId == ticket.id) ...[
                const SizedBox(height: 8),
                Text(
                  'eligibility: ${_recoveryAssessment!.eligibility.name}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _actionInProgress == ticket.id ? null : () => _recoveryPreview(ticket.id),
                  child: const Text('복구 preview'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _actionInProgress == ticket.id ? null : () => _createRecoveryTicket(ticket.id),
                  child: const Text('복구 티켓 생성'),
                ),
              ),
            ],
            if (_dryRunPreview != null && _dryRunPreview!.ticketId == ticket.id) ...[
              const SizedBox(height: 12),
              const Text('Dry-run Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: SingleChildScrollView(
                  child: Text(_dryRunPreview!.summary, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
            if (_executionLogs.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('실행 기록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ..._executionLogs.map(
                (log) => Text(
                  '${log.resultStatus.name} · ${log.action} · ${log.errorMessage ?? 'ok'}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
            if (ticket.errorMessage != null)
              Text('오류 요약: ${ticket.errorMessage}', style: const TextStyle(fontSize: 16)),
            if (ticket.status == WorkQueueTicketStatus.conflict)
              const Text(
                '상태: 충돌 — 사용자 확인 필요',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '작업큐 / 티켓',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildSummaryCard(_summary!),
                const SizedBox(height: 12),
                const Text('대기 중인 티켓', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_pending.isEmpty)
                  const Text('(없음)', style: TextStyle(fontSize: 16))
                else
                  ..._pending.map((ticket) {
                    final selected = _selected?.id == ticket.id;
                    return Card(
                      child: ListTile(
                        selected: selected,
                        title: Text(
                          '${ticket.isRecoveryTicket ? '[복구] ' : ''}${ticket.requestedAction} · ${_permissionLabel(ticket.permissionLevel)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        subtitle: Text(
                          '${_statusLabel(ticket.status)} · ${ticket.actor}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        onTap: () {
                          setState(() {
                            _selected = ticket;
                            _dryRunPreview = null;
                            _recoveryAssessment = null;
                          });
                          _loadExecutionLogs(ticket.id);
                        },
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                const Text('전체 티켓', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._all.map((ticket) {
                  final selected = _selected?.id == ticket.id;
                  return Card(
                    child: ListTile(
                      selected: selected,
                      title: Text(
                        '${ticket.isRecoveryTicket ? '[복구] ' : ''}${ticket.requestedAction} · ${_permissionLabel(ticket.permissionLevel)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      subtitle: Text(
                        '${_statusLabel(ticket.status)} · ${ticket.actor}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () {
                        setState(() {
                          _selected = ticket;
                          _dryRunPreview = null;
                          _recoveryAssessment = null;
                        });
                        _loadExecutionLogs(ticket.id);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _selected != null
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildDetailPanel(_selected!),
                  )
                : const Center(
                    child: Text('티켓을 선택하세요', style: TextStyle(fontSize: 16)),
                  ),
          ),
        ],
      ),
    );
  }
}
