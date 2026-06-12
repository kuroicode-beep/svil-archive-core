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
        await db.execute('PRAGMA busy_timeout=5000');
      },
      onCreate: (db, version) async {
        await applySacMigrations(db, 0, version);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await applySacMigrations(db, oldVersion, newVersion);
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
    final current = await getSchemaVersion();
    await applySacMigrations(db, current, targetVersion);
    await db.execute('PRAGMA user_version = $targetVersion');
  }

  @override
  Future<void> reset() async {
    final db = requireDatabase();
    await db.transaction((txn) async {
      for (final table in [
        'document_fts',
        'document_chunks',
        'sync_journal',
        'sync_state',
        'trash_items',
        'import_queue',
        'documents',
        'workspaces',
        'app_settings',
      ]) {
        try {
          await txn.delete(table);
        } catch (_) {}
      }
    });
  }

  @override
  Future<String> createSnapshot(String destinationPath) async {
    throw UnimplementedError('createSnapshot is planned for Sprint 4+');
  }

  @override
  Future<bool> isOpen() async => _db != null && _db!.isOpen;
}
