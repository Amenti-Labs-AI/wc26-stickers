import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/data/database/app_database.dart';
import 'package:panini_wc26_tracker/data/models/collection_start_mode.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wc26_db_test_');
    db = AppDatabase.instance;
    await db.debugClose();
    db.debugDatabasePath = p.join(tempDir.path, 'test.db');
  });

  tearDown(() async {
    await db.debugClose();
    db.debugDatabasePath = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('seeds catalog and reports stats after open', () async {
    final stats = await db.getStats();
    expect(stats.total, greaterThan(900));
    expect(stats.owned, lessThanOrEqualTo(stats.total));
  });

  test('applyCollectionStartMode ownedScan marks setup complete', () async {
    expect(await db.hasCompletedCollectionSetup(), isFalse);
    await db.applyCollectionStartMode(CollectionStartMode.ownedScan);
    expect(await db.hasCompletedCollectionSetup(), isTrue);
    final stats = await db.getStats();
    expect(stats.owned, stats.total);
  });

  test('resetCollection allMissing clears ownership', () async {
    await db.applyCollectionStartMode(CollectionStartMode.ownedScan);
    await db.resetCollection(CollectionStartMode.allMissing);
    final stats = await db.getStats();
    expect(stats.owned, 0);
  });

  test('collection backup export/import round-trip', () async {
    await db.applyCollectionStartMode(CollectionStartMode.allMissing);
    final before = await db.exportCollectionBackupJson();
    expect(before, contains('collection_backup'));

    await db.resetCollection(CollectionStartMode.ownedScan);
    expect((await db.getStats()).owned, greaterThan(0));

    await db.importCollectionBackupJson(before, replace: true);
    final after = await db.exportCollectionBackupJson();
    expect(after, contains('"type":"collection_backup"'));
    expect((await db.getStats()).owned, 0);
  });
}
