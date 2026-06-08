// privacy_screen.dart — 개인정보 보호 화면 (Sprint 8)

import 'package:flutter/material.dart';

import '../../domain/models/dashboard.dart';
import '../../domain/services/privacy_service.dart';
import '../widgets/privacy_status_panel.dart';

class PrivacyScreen extends StatefulWidget {
  final PrivacyService privacyService;

  const PrivacyScreen({super.key, required this.privacyService});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  PrivacySummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// 개인정보 요약을 다시 로드한다.
  Future<void> _refresh() async {
    setState(() => _loading = true);
    final summary = await widget.privacyService.getPrivacySummary();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
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
              '개인정보 보호',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            PrivacyStatusPanel(summary: summary),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('MCP / 작업큐 정책', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('외부 MCP: 비활성화', style: TextStyle(fontSize: 16)),
                    Text('원격 포트: 열지 않음', style: TextStyle(fontSize: 16)),
                    Text('쓰기 작업: queue 승인 후 실행', style: TextStyle(fontSize: 16)),
                    Text('파괴적 작업: destructive token + 승인 + 2단계 확인', style: TextStyle(fontSize: 16)),
                    Text('실행 로그: 본문·token 값 미저장', style: TextStyle(fontSize: 16)),
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
                  children: const [
                    Text('무결성 정책', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('자동 삭제: 비활성화', style: TextStyle(fontSize: 16)),
                    Text('orphan Markdown 자동 삭제: 금지', style: TextStyle(fontSize: 16)),
                    Text('create_document orphan overwrite: 차단', style: TextStyle(fontSize: 16)),
                    Text('실행 복구: 새 recovery ticket만 허용', style: TextStyle(fontSize: 16)),
                    Text('스캔/감사/smoke notes: 민감 본문 미저장', style: TextStyle(fontSize: 16)),
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
                    const Text('Release / RC 정책', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'RC 차단 항목: ${summary.releaseBlockingCount}건',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      '보고서 정합성: ${summary.reportConsistent ? '일치' : '불일치'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      summary.releaseReadiness?.rcStatusLabel ?? 'RC 미평가',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      summary.releaseExportPolicyLabel,
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      summary.knownIssuesPolicyLabel,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Text('자동 배포·코드 서명: 범위 외', style: TextStyle(fontSize: 16)),
                    const Text('외부 API: 기본 OFF', style: TextStyle(fontSize: 16)),
                    const Text('remote MCP: 비활성', style: TextStyle(fontSize: 16)),
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
                  children: const [
                    Text('LLM용 문서 생성 정책', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('외부 전송: 비활성화', style: TextStyle(fontSize: 16)),
                    Text('자동 승인: 비활성화', style: TextStyle(fontSize: 16)),
                    Text('pending 후보는 LLM용 문서에 포함되지 않음', style: TextStyle(fontSize: 16)),
                    Text('rejected 후보는 개인 아카이브에 저장되지 않음', style: TextStyle(fontSize: 16)),
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
                    const Text(
                      '최근 개인 데이터 관련 감사 로그',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (summary.recentPrivacyAuditLogs.isEmpty)
                      const Text('(없음)', style: TextStyle(fontSize: 16))
                    else
                      ...summary.recentPrivacyAuditLogs.map(
                        (log) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${log.action} · ${log.targetType} · ${log.targetId ?? '-'} · ${log.occurredAt}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
