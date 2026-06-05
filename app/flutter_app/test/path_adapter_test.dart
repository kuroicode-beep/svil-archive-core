// path_adapter_test.dart — workspace 경계 및 path traversal 방지 테스트

import 'package:flutter_test/flutter_test.dart';
import 'package:sac_app/data/platform/path_adapter.dart';

void main() {
  const workspaceRoot = r'C:\Users\test\SAC DOCS';

  test('resolveWorkspacePath blocks parent traversal', () {
    expect(
      () => resolveWorkspacePath(workspaceRoot, 'documents/../../outside/file.md'),
      throwsA(isA<WorkspacePathException>()),
    );
  });

  test('resolveWorkspacePath allows valid document path', () {
    final resolved = resolveWorkspacePath(
      workspaceRoot,
      'documents/Dev/sample.md',
    );
    expect(resolved.contains('documents'), isTrue);
    expect(resolved.contains('Dev'), isTrue);
  });

  test('sanitizeDocumentCategory rejects unknown category', () {
    expect(
      () => sanitizeDocumentCategory('../../outside'),
      throwsA(isA<WorkspacePathException>()),
    );
  });

  test('resolveCreateDocumentRelativePath uses relativeDir', () {
    final path = resolveCreateDocumentRelativePath(
      relativeDir: 'documents/Log',
      type: 'Dev',
      title: 'My Note',
    );
    expect(path, 'documents/Log/My_Note.md');
  });

  test('buildDocumentRelativePath rejects traversal in category', () {
    expect(
      () => buildDocumentRelativePath('../outside', 'note.md'),
      throwsA(isA<WorkspacePathException>()),
    );
  });
}
