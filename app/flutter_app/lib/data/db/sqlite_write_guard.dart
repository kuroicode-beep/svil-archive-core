// sqlite_write_guard.dart — SQLite write 직렬화 (단일 writer 경로)

import 'dart:async';

/// 여러 writer가 동시에 DB에 쓰지 않도록 직렬화한다 (재진입 허용).
class SqliteWriteGuard {
  Future<void> _tail = Future<void>.value();
  int _depth = 0;

  /// write 작업을 직렬 큐에 넣어 실행한다.
  Future<T> run<T>(Future<T> Function() operation) {
    if (_depth > 0) {
      return operation();
    }

    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      _depth++;
      try {
        completer.complete(await operation());
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        _depth--;
      }
    });
    return completer.future;
  }
}
