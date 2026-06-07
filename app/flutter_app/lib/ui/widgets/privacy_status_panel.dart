// privacy_status_panel.dart — 개인정보 보호 상태 요약 패널

import 'package:flutter/material.dart';

import '../../domain/models/dashboard.dart';

class PrivacyStatusPanel extends StatelessWidget {
  final PrivacySummary summary;

  const PrivacyStatusPanel({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '개인정보 보호 상태',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _statusRow('로컬 처리', summary.localProcessingEnabled ? '활성화' : '비활성화'),
            _statusRow('외부 전송', summary.externalTransferEnabled ? '활성화' : '비활성화'),
            _statusRow('자동 승인', '비활성화'),
            _statusRow('승인 대기 후보', '${summary.pendingCandidateCount}건'),
            _statusRow('승인된 개인 항목', '${summary.activePersonalItemCount}건'),
            const SizedBox(height: 8),
            Text(
              'Export 정책: ${summary.exportPolicyLabel}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'MCP / 권한',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            _statusRow('외부 MCP', summary.mcpPrivacy.remoteMcpEnabled ? '활성화' : '비활성화'),
            _statusRow('로컬 전용', summary.mcpPrivacy.localOnly ? '예' : '아니오'),
            _statusRow('write token', '${summary.mcpPrivacy.writeTokenCount}건'),
            _statusRow('destructive token', '${summary.mcpPrivacy.destructiveTokenCount}건'),
            _statusRow('personal token', '${summary.mcpPrivacy.personalTokenCount}건'),
            _statusRow('활성 MCP tool', '${summary.mcpPrivacy.enabledToolCount}건'),
            _statusRow('비활성 MCP tool', '${summary.mcpPrivacy.disabledToolCount}건'),
            const SizedBox(height: 12),
            const Text(
              '작업큐 실행',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            _statusRow('실행 대기(approved)', '${summary.executionSummary.approvedReadyCount}건'),
            _statusRow('실행 완료', '${summary.executionSummary.completedCount}건'),
            _statusRow('실행 실패', '${summary.executionSummary.executionFailedCount}건'),
            _statusRow('충돌(conflict)', '${summary.executionSummary.conflictCount}건'),
            const SizedBox(height: 12),
            const Text(
              '무결성 / 보고서',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            _statusRow('orphan Markdown', '${summary.integritySummary.openOrphanCount}건'),
            _statusRow('stale DB row', '${summary.integritySummary.openStaleDbCount}건'),
            _statusRow('보고서 정합성', summary.reportConsistent ? '일치' : '불일치'),
          ],
        ),
      ),
    );
  }

  /// 상태 행을 생성한다.
  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 16)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
