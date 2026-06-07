// workspace_file_inventory_service_impl.dart — workspace Markdown 인벤토리 구현

import '../../domain/services/document_file_store.dart';
import '../../domain/services/workspace_file_inventory_service.dart';

/// 스캔에서 제외할 경로 prefix.
const Set<String> kExcludedMarkdownPrefixes = {
  '.sac/',
  'exports/',
};

class WorkspaceFileInventoryServiceImpl implements WorkspaceFileInventoryService {
  final DocumentFileStore _fileStore;

  WorkspaceFileInventoryServiceImpl({required DocumentFileStore fileStore})
      : _fileStore = fileStore;

  @override
  Future<List<String>> listWorkspaceMarkdownPaths() async {
    final all = await _fileStore.listMarkdownFiles('documents');
    return all.where(_isScannablePath).toList()..sort();
  }

  /// 무결성 스캔 대상 경로인지 확인한다.
  bool _isScannablePath(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    for (final prefix in kExcludedMarkdownPrefixes) {
      if (normalized.startsWith(prefix)) return false;
    }
    if (normalized.contains('/.sac/')) return false;
    return normalized.endsWith('.md');
  }
}
