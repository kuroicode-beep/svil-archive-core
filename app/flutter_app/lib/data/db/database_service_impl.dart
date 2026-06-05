// database_service_impl.dart — SQLite 초기화 및 WAL 모드 구현

import 'package:sqflite/sqflite.dart';

import '../../domain/services/database_service.dart';
import 'migrations.dart';

class DatabaseServiceImpl implements DatabaseService {
  Database? _db;
  String? _dbPath;

  @override
  Future<void> initialize(String dbPath) async {
    if (_db != null && _dbPath == dbPath) {
      return;
    }
    await close();
    _dbPath = dbPath;
    _db = await openDatabase(
      dbPath,
      version: kSacSchemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA foreign_keys=ON');
      },
      onCreate: (db, version) async {
        for (final sql in sprint2MigrationSql()) {
          await db.execute(sql);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (final sql in sprint2MigrationSql()) {
          await db.execute(sql);
        }
      },
    );
  }

  /// 내부 DB 인스턴스를 반환한다.
  Database requireDatabase() {
    final db = _db;
    if (db == null) {
      throw StateError('Database is not initialized');
    }
    return db;
  }

  @override
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _dbPath = null;
    }
  }

  @override
  Future<int> getSchemaVersion() async {
    final db = requireDatabase();
    final rows = await db.rawQuery('PRAGMA user_version');
    return rows.first['user_version'] as int? ?? 0;
  }

  @override
  Future<void> migrate(int targetVersion) async {
    final db = requireDatabase();
    for (final sql in sprint2MigrationSql()) {
      await db.execute(sql);
    }
    await db.execute('PRAGMA user_version = $targetVersion');
  }

  @override
  Future<void> reset() async {
    final db = requireDatabase();
    await db.transaction((txn) async {
      for (final table in [
        'sync_journal',
        'sync_state',
        'documents',
        'workspaces',
        'app_settings',
      ]) {
        await txn.delete(table);
      }
    });
  }

  @override
  Future<String> createSnapshot(String destinationPath) async {
    // Sprint 2: 파일 복사는 후속 Sprint에서 구현
    throw UnimplementedError('createSnapshot is planned for Sprint 3+');
  }

  @override
  Future<bool> isOpen() async => _db != null && _db!.isOpen;
}
