// RightContextPanel: 우측 컨텍스트 패널 placeholder — 문서 메타, TTS 컨트롤

import 'package:flutter/material.dart';

class RightContextPanel extends StatelessWidget {
  const RightContextPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('컨텍스트 패널',
              style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          const Text('문서 선택 시 메타데이터 표시됩니다.',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const Spacer(),
          // TTS 컨트롤 stub
          _TtsControlStub(),
        ],
      ),
    );
  }
}

class _TtsControlStub extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TTS', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              iconSize: 30,
              tooltip: '읽기 시작',
              onPressed: () {
                // TODO(Cursor): TtsService.speakDocument 연결
              },
            ),
            IconButton(
              icon: const Icon(Icons.pause),
              iconSize: 30,
              tooltip: '일시정지',
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              iconSize: 30,
              tooltip: '정지',
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}
