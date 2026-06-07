// sync_status_badge.dart — sync 상태 라벨 + 색상 배지

import 'package:flutter/material.dart';

import '../../domain/models/sync_state.dart';

class SyncStatusBadge extends StatelessWidget {
  final SyncStatus status;
  final bool compact;

  const SyncStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  /// 상태별 한글 라벨을 반환한다.
  static String labelFor(SyncStatus status) {
    switch (status) {
      case SyncStatus.clean:
        return '동기화됨';
      case SyncStatus.dirty:
        return '변경 감지';
      case SyncStatus.userModified:
        return '사용자 수정';
      case SyncStatus.aiPending:
        return 'AI 대기';
      case SyncStatus.conflict:
        return '충돌';
      case SyncStatus.trashed:
        return '휴지통';
    }
  }

  /// 상태별 강조 색상을 반환한다.
  static Color colorFor(SyncStatus status) {
    switch (status) {
      case SyncStatus.clean:
        return Colors.green.shade700;
      case SyncStatus.dirty:
        return Colors.orange.shade800;
      case SyncStatus.userModified:
        return Colors.blue.shade700;
      case SyncStatus.aiPending:
        return Colors.purple.shade700;
      case SyncStatus.conflict:
        return Colors.red.shade700;
      case SyncStatus.trashed:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = labelFor(status);
    final color = colorFor(status);
    if (compact) {
      return Tooltip(
        message: label,
        child: Icon(Icons.circle, size: 10, color: color),
      );
    }
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: const TextStyle(fontSize: 13)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
    );
  }
}
