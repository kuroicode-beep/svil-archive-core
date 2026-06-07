// work_queue_panel.dart — 작업큐 / 티켓 화면 (Sprint 7)

import 'package:flutter/material.dart';

import '../../domain/models/work_queue.dart';
import '../../domain/services/work_queue_service.dart';

class WorkQueuePanel extends StatefulWidget {
  final WorkQueueService workQueueService;

  const WorkQueuePanel({
    super.key,
    required this.workQueueService,
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
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _pending = pending;
      _all = all;
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
          ],
        ),
      ),
    );
  }

  /// 티켓 상세 패널을 구성한다.
  Widget _buildDetailPanel(WorkQueueTicket ticket) {
    final isDestructive = ticket.permissionLevel == PermissionLevel.destructive;
    final canAct = ticket.status == WorkQueueTicketStatus.pending;

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
            if (ticket.targetPath != null)
              Text('경로: ${ticket.targetPath}', style: const TextStyle(fontSize: 16)),
            if (ticket.reason != null)
              Text('사유: ${ticket.reason}', style: const TextStyle(fontSize: 16)),
            Text(
              '생성: ${ticket.createdAt.toLocal()}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (canAct) ...[
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
                          '${ticket.requestedAction} · ${_permissionLabel(ticket.permissionLevel)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        subtitle: Text(
                          '${_statusLabel(ticket.status)} · ${ticket.actor}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        onTap: () => setState(() => _selected = ticket),
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
                        '${ticket.requestedAction} · ${_permissionLabel(ticket.permissionLevel)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      subtitle: Text(
                        '${_statusLabel(ticket.status)} · ${ticket.actor}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () => setState(() => _selected = ticket),
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
