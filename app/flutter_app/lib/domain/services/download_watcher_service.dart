// download_watcher_service.dart — 다운로드 폴더 감시 서비스 인터페이스 (Sprint 16)

import '../models/import_queue_item.dart';

abstract class DownloadWatcherService {
  /// 다운로드 폴더를 1회 스캔하여 prefix 일치 .md를 Import Queue에 등록한다.
  /// 새로 등록된 항목 목록을 반환한다.
  Future<List<ImportQueueItem>> scanOnce();

  /// 감시(파일 이벤트 + 주기 스캔)를 시작한다.
  Future<void> start();

  /// 감시를 중지한다.
  Future<void> stop();

  /// 현재 감시 중인지 여부.
  bool get isRunning;

  /// 감시 대상 폴더 절대경로(설정 없으면 기본 Downloads).
  String get resolvedFolderPath;
}
