// ai_collaboration_status_panel.dart — AI 협업 프로토콜 현황 패널

import 'package:flutter/material.dart';

import '../../domain/models/dashboard.dart';

class AiCollaborationStatusPanel extends StatelessWidget {
  final AiCollaborationSummary summary;

  const AiCollaborationStatusPanel({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI 협업 프로토콜 현황',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _metricChip('진행 중 작업지시문', summary.activeWorkInstructions),
                _metricChip('핸드오프 대기', summary.handoffPending),
                _metricChip('검증 필요', summary.verificationNeeded),
                _metricChip('Critical 이슈', summary.criticalIssues),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '최근 완료 Sprint: ${summary.lastCompletedSprint}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// 지표 칩을 생성한다.
  Widget _metricChip(String label, int value) {
    return Chip(
      label: Text('$label: $value', style: const TextStyle(fontSize: 14)),
    );
  }
}
