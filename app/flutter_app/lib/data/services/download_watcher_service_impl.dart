// download_watcher_service_impl.dart — 다운로드 폴더 감시 구현 (Sprint 16)

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import '../../domain/models/import_queue_item.dart';
import '../../domain/models/settings.dart';
import '../../domain/services/download_watcher_service.dart';
import '../../domain/services/import_queue_service.dart';
import '../import/ai_sync_prefix.dart';

class DownloadWatcherServiceImpl implements DownloadWatcherService {
  final ImportQueueService _queueService;
  final Future<DownloadWatcherSettings> Function() _settingsProvider;
  final void Function()? onQueueChanged;

  DirectoryWatcher? _watcher;
  StreamSubscription<WatchEvent>? _subscription;
  Timer? _fallbackTimer;
  Timer? _debounceTimer;
  bool _running = false;
  DownloadWatcherSettings _lastSettings = const DownloadWatcherSettings();

  DownloadWatcherServiceImpl({
    required ImportQueueService queueService,
    required Future<DownloadWatcherSettings> Function() settingsProvider,
    this.onQueueChanged,
  })  : _queueService = queueService,
        _settingsProvider = settingsProvider;

  @override
  bool get isRunning => _running;

  @override
  String get resolvedFolderPath => _resolveFolder(_lastSettings);

  /// 설정 기준 감시 폴더 절대경로를 계산한다.
  String _resolveFolder(DownloadWatcherSettings settings) {
    final configured = settings.folderPath.trim();
    if (configured.isNotEmpty) return p.normalize(configured);
    return _defaultDownloadsFolder();
  }

  /// OS 기본 다운로드 폴더를 추정한다.
  String _defaultDownloadsFolder() {
    final env = Platform.environment;
    final home = env['USERPROFILE'] ?? env['HOME'] ?? Directory.current.path;
    return p.normalize(p.join(home, 'Downloads'));
  }

  @override
  Future<List<ImportQueueItem>> scanOnce() async {
    final settings = await _settingsProvider();
    _lastSettings = settings;
    final folder = _resolveFolder(settings);
    final dir = Directory(folder);
    if (!await dir.exists()) {
      return const [];
    }

    final enqueued = <ImportQueueItem>[];
    final entities = dir.list(recursive: settings.includeSubfolders, followLinks: false);
    await for (final entity in entities) {
      if (entity is! File) continue;
      if (p.extension(entity.path).toLowerCase() != '.md') continue;

      final fileName = p.basename(entity.path);
      final match = stripAiSyncPrefix(fileName, prefixes: settings.prefixes);
      // 감지 조건: 등록된 prefix 중 하나로 시작해야 한다.
      if (!match.hasPrefix) continue;

      int size;
      try {
        size = await entity.length();
      } catch (_) {
        continue;
      }

      final item = await _queueService.enqueueDetected(
        sourceAbsolutePath: p.normalize(entity.path),
        originalFileName: fileName,
        matchedPrefix: match.matchedPrefix,
        targetFileName: match.strippedFileName,
        sourceAi: match.sourceAi,
        fileSize: size,
      );
      if (item != null) {
        enqueued.add(item);
      }
    }
    if (enqueued.isNotEmpty) {
      onQueueChanged?.call();
    }
    return enqueued;
  }

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    final settings = await _settingsProvider();
    _lastSettings = settings;
    final folder = _resolveFolder(settings);

    // 시작 시 1회 스캔으로 기존 파일을 회수한다.
    await scanOnce();

    if (await Directory(folder).exists()) {
      try {
        _watcher = DirectoryWatcher(folder);
        _subscription = _watcher!.events.listen(
          (_) => _scheduleDebouncedScan(),
          onError: (_) {},
        );
      } catch (_) {
        _watcher = null;
      }
    }

    // 이벤트 감지 실패 대비 주기 fallback 스캔.
    final interval = Duration(
      minutes: settings.scanIntervalMinutes > 0 ? settings.scanIntervalMinutes : 5,
    );
    _fallbackTimer = Timer.periodic(interval, (_) => scanOnce());
  }

  /// 파일 이벤트를 debounce 후 스캔으로 변환한다 (작성 완료 대기).
  void _scheduleDebouncedScan() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 10), () {
      if (_running) scanOnce();
    });
  }

  @override
  Future<void> stop() async {
    _running = false;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _watcher = null;
  }
}
