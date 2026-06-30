import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/parallel_kind.dart';
import '../../core/sticker_search_query.dart';
import '../models/sticker.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'panini_wc26.db');
    return openDatabase(
      path,
      version: 7,
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedCatalog(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _dedupeTables(db);
        if (oldVersion < 3) {
          await _createScannedMissingTable(db);
        }
        if (oldVersion < 4) {
          await _defaultCollectionToOwned(db);
        }
        if (oldVersion < 5) {
          await _defaultCollectionToOwned(db);
          await db.execute('''
            UPDATE collection
            SET owned_count = 1
            WHERE code IN (SELECT code FROM scanned_missing)
              AND owned_count = 0
          ''');
        }
        if (oldVersion < 6) {
          await _syncCatalogFromAsset(db);
        }
        if (oldVersion < 7) {
          await _createParallelInventoryTable(db);
        }
      },
      onOpen: (db) async {
        await _dedupeTables(db);
        await _createScannedMissingTable(db);
        await _createParallelInventoryTable(db);
        await _ensureCollectionRows(db);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE catalog (
        code TEXT PRIMARY KEY,
        team_code TEXT NOT NULL,
        team_name TEXT NOT NULL,
        slot_number INTEGER NOT NULL,
        player_name TEXT,
        category TEXT NOT NULL,
        grp TEXT NOT NULL,
        album_page INTEGER,
        slot_index_on_page INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE collection (
        code TEXT PRIMARY KEY,
        owned_count INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (code) REFERENCES catalog(code)
      )
    ''');
    await _createScannedMissingTable(db);
    await _createParallelInventoryTable(db);
  }

  Future<void> _createParallelInventoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS parallel_inventory (
        code TEXT NOT NULL,
        kind TEXT NOT NULL,
        count INTEGER NOT NULL DEFAULT 0 CHECK(count >= 0 AND count <= 999),
        PRIMARY KEY (code, kind),
        FOREIGN KEY (code) REFERENCES catalog(code)
      )
    ''');
  }

  Future<void> _defaultCollectionToOwned(Database db) async {
    await db.execute('''
      UPDATE collection
      SET owned_count = 1
      WHERE owned_count = 0
        AND code NOT IN (SELECT code FROM scanned_missing)
    ''');
  }

  Future<void> _createScannedMissingTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scanned_missing (
        code TEXT PRIMARY KEY,
        last_seen_at INTEGER NOT NULL,
        FOREIGN KEY (code) REFERENCES catalog(code)
      )
    ''');
  }

  /// Remove duplicate rows if a prior bug double-seeded the catalog.
  Future<void> _dedupeTables(Database db) async {
    await db.execute('''
      DELETE FROM catalog
      WHERE rowid NOT IN (SELECT MIN(rowid) FROM catalog GROUP BY code)
    ''');
    await db.execute('''
      DELETE FROM collection
      WHERE rowid NOT IN (SELECT MIN(rowid) FROM collection GROUP BY code)
    ''');
  }

  /// Every catalog sticker must have a collection row (JOIN in list queries).
  Future<void> _ensureCollectionRows(Database db) async {
    await db.execute('''
      INSERT OR IGNORE INTO collection (code, owned_count)
      SELECT code, 1 FROM catalog
    ''');
  }

  Future<void> _seedCatalog(Database db) async {
    final raw = await rootBundle.loadString('assets/catalog/wc26_catalog.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final stickers = data['stickers'] as List<dynamic>;
    final batch = db.batch();
    for (final item in stickers) {
      final m = item as Map<String, dynamic>;
      batch.insert('catalog', {
        'code': m['code'],
        'team_code': m['team_code'],
        'team_name': m['team_name'],
        'slot_number': m['slot_number'],
        'player_name': m['player_name'],
        'category': m['category'],
        'grp': m['group'],
        'album_page': m['album_page'],
        'slot_index_on_page': m['slot_index_on_page'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      batch.insert('collection', {
        'code': m['code'],
        'owned_count': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  /// Replace catalog metadata from bundled JSON; drop removed codes (e.g. CC13–14).
  Future<void> _syncCatalogFromAsset(Database db) async {
    final raw = await rootBundle.loadString('assets/catalog/wc26_catalog.json');
    final stickers = (jsonDecode(raw) as Map<String, dynamic>)['stickers']
        as List<dynamic>;
    final codes = <String>{};

    await db.transaction((txn) async {
      for (final item in stickers) {
        final m = item as Map<String, dynamic>;
        final code = m['code'] as String;
        codes.add(code);
        await txn.insert(
          'catalog',
          {
            'code': code,
            'team_code': m['team_code'],
            'team_name': m['team_name'],
            'slot_number': m['slot_number'],
            'player_name': m['player_name'],
            'category': m['category'],
            'grp': m['group'],
            'album_page': m['album_page'],
            'slot_index_on_page': m['slot_index_on_page'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final existing = await txn.query('catalog', columns: ['code']);
      for (final row in existing) {
        final code = row['code']! as String;
        if (codes.contains(code)) continue;
        await txn.delete('catalog', where: 'code = ?', whereArgs: [code]);
        await txn.delete('collection', where: 'code = ?', whereArgs: [code]);
        await txn.delete(
          'scanned_missing',
          where: 'code = ?',
          whereArgs: [code],
        );
        await txn.delete(
          'parallel_inventory',
          where: 'code = ?',
          whereArgs: [code],
        );
      }

      await txn.execute('''
        INSERT OR IGNORE INTO collection (code, owned_count)
        SELECT code, 1 FROM catalog
      ''');
    });
  }

  Future<List<Sticker>> getAllStickers({
    String? query,
    StickerFilter filter = StickerFilter.all,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];

    if (query != null && query.trim().isNotEmpty) {
      final parsed = StickerSearchQuery.parse(query);
      switch (parsed.kind) {
        case StickerSearchKind.none:
          where.add('0 = 1');
        case StickerSearchKind.teamCode:
          where.add('c.team_code = ?');
          args.add(parsed.teamCode);
        case StickerSearchKind.exactCode:
          where.add('c.code = ?');
          args.add(parsed.code);
      }
    }

    if (filter == StickerFilter.scannedMissing) {
      final sql = '''
        SELECT c.*, col.owned_count AS owned_count
        FROM scanned_missing sm
        JOIN catalog c ON c.code = sm.code
        JOIN collection col ON c.code = col.code
        ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
        ORDER BY
          CASE c.grp
            WHEN 'FWC' THEN 0
            WHEN 'Coca-Cola' THEN 999
            ELSE 1
          END,
          c.grp,
          c.team_code,
          c.slot_number
      ''';
      final rows = await db.rawQuery(sql, args);
      final parallelByCode = await getAllParallelCounts();
      return rows
          .map((row) => _rowToSticker(row, parallelByCode))
          .toList();
    }

    switch (filter) {
      case StickerFilter.owned:
        where.add('col.owned_count >= 1');
      case StickerFilter.missing:
        where.add('col.owned_count = 0');
      case StickerFilter.scannedMissing:
        break;
      case StickerFilter.duplicates:
        where.add('''
          (col.owned_count >= 2 OR EXISTS (
            SELECT 1 FROM parallel_inventory pi
            WHERE pi.code = c.code AND pi.count > 0
          ))
        ''');
      case StickerFilter.all:
        break;
    }

    final sql = '''
      SELECT c.*, col.owned_count AS owned_count
      FROM catalog c
      JOIN collection col ON c.code = col.code
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY
        CASE c.grp
          WHEN 'FWC' THEN 0
          WHEN 'Coca-Cola' THEN 999
          ELSE 1
        END,
        c.grp,
        c.team_code,
        c.slot_number
    ''';

    final rows = await db.rawQuery(sql, args);
    final parallelByCode = await getAllParallelCounts();
    return rows
        .map((row) => _rowToSticker(row, parallelByCode))
        .toList();
  }

  Future<Map<String, Map<ParallelKind, int>>> getAllParallelCounts() async {
    final db = await database;
    final rows = await db.query(
      'parallel_inventory',
      where: 'count > 0',
    );
    final result = <String, Map<ParallelKind, int>>{};
    for (final row in rows) {
      final code = (row['code']! as String).toUpperCase();
      final kind = ParallelKind.fromStorageKey(row['kind']! as String);
      if (kind == null) continue;
      final count = row['count']! as int;
      result.putIfAbsent(code, () => {})[kind] = count;
    }
    return result;
  }

  Future<Map<ParallelKind, int>> getParallelCountsForCode(String code) async {
    final db = await database;
    final upper = code.toUpperCase();
    final rows = await db.query(
      'parallel_inventory',
      where: 'code = ? AND count > 0',
      whereArgs: [upper],
    );
    final result = <ParallelKind, int>{};
    for (final row in rows) {
      final kind = ParallelKind.fromStorageKey(row['kind']! as String);
      if (kind == null) continue;
      result[kind] = row['count']! as int;
    }
    return result;
  }

  Future<void> setParallelCount(
    String code,
    ParallelKind kind,
    int count,
  ) async {
    final upper = code.toUpperCase();
    final clamped = count.clamp(0, 999);
    final db = await database;
    if (clamped == 0) {
      await db.delete(
        'parallel_inventory',
        where: 'code = ? AND kind = ?',
        whereArgs: [upper, kind.storageKey],
      );
      return;
    }
    await db.insert(
      'parallel_inventory',
      {
        'code': upper,
        'kind': kind.storageKey,
        'count': clamped,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> applyParallelCounts(
    String code,
    Map<ParallelKind, int> counts,
  ) async {
    final upper = code.toUpperCase();
    final db = await database;
    await db.transaction((txn) async {
      for (final kind in ParallelKind.values) {
        final count = (counts[kind] ?? 0).clamp(0, 999);
        if (count == 0) {
          await txn.delete(
            'parallel_inventory',
            where: 'code = ? AND kind = ?',
            whereArgs: [upper, kind.storageKey],
          );
        } else {
          await txn.insert(
            'parallel_inventory',
            {
              'code': upper,
              'kind': kind.storageKey,
              'count': count,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Sticker _rowToSticker(
    Map<String, Object?> row, [
    Map<String, Map<ParallelKind, int>>? parallelByCode,
  ]) {
    final code = row['code']! as String;
    return Sticker(
        code: code,
        teamCode: row['team_code']! as String,
        teamName: row['team_name']! as String,
        slotNumber: row['slot_number']! as int,
        playerName: row['player_name'] as String?,
        category: row['category']! as String,
        group: row['grp']! as String,
        albumPage: row['album_page'] as int?,
        slotIndexOnPage: row['slot_index_on_page'] as int?,
        ownedCount: row['owned_count']! as int,
        parallelCounts: parallelByCode?[code.toUpperCase()] ??
            const <ParallelKind, int>{},
      );
  }

  Future<Sticker?> getSticker(String code) async {
    final upper = code.toUpperCase();

    final db = await database;
    final rows = await db.rawQuery('''
      SELECT c.*, col.owned_count AS owned_count
      FROM catalog c
      JOIN collection col ON c.code = col.code
      WHERE c.code = ?
    ''', [upper]);
    if (rows.isEmpty) return null;
    final parallelByCode = await getAllParallelCounts();
    return _rowToSticker(rows.first, parallelByCode);
  }

  Future<Map<String, String>> getDisplayNamesByCodes(Iterable<String> codes) async {
    if (codes.isEmpty) return {};

    final db = await database;
    final placeholders = List.filled(codes.length, '?').join(',');
    final upper = codes.map((c) => c.toUpperCase()).toList();
    final rows = await db.rawQuery(
      'SELECT code, player_name, team_name, category FROM catalog WHERE code IN ($placeholders)',
      upper,
    );
    final result = <String, String>{};
    for (final row in rows) {
      result[row['code']! as String] = _displayNameFromRow(row);
    }
    return result;
  }

  String _displayNameFromRow(Map<String, dynamic> row) {
    final player = row['player_name'] as String?;
    final team = row['team_name']! as String;
    final cat = row['category']! as String;
    if (player != null && player.isNotEmpty) return player;
    if (cat == 'badge') return '$team Badge';
    if (cat == 'team_photo') return '$team Team Photo';
    return row['code']! as String;
  }

  Future<void> setOwnedCount(String code, int count) async {
    final upper = code.toUpperCase();
    final db = await database;
    await db.update(
      'collection',
      {'owned_count': count.clamp(0, 999)},
      where: 'code = ?',
      whereArgs: [upper],
    );
  }

  Future<void> incrementOwned(String code, {int by = 1}) async {
    final sticker = await getSticker(code.toUpperCase());
    if (sticker == null) return;
    await setOwnedCount(code, sticker.ownedCount + by);
  }

  /// Sticker codes with owned_count >= 1 (already in collection).
  Future<Set<String>> getOwnedStickerCodes() async {
    final db = await database;
    final rows = await db.query(
      'collection',
      columns: ['code'],
      where: 'owned_count >= 1',
    );
    return rows.map((r) => (r['code'] as String).toUpperCase()).toSet();
  }

  /// Records empty slots detected by the live scan (Missing tab source).
  Future<void> mergeScannedMissingCodes(Iterable<String> codes) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final db = await database;
    await db.transaction((txn) async {
      for (final raw in codes) {
        final code = raw.toUpperCase();
        final exists = await txn.rawQuery(
          'SELECT 1 FROM catalog WHERE code = ? LIMIT 1',
          [code],
        );
        if (exists.isEmpty) continue;

        await txn.insert(
          'scanned_missing',
          {'code': code, 'last_seen_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> clearScannedMissing() async {
    final db = await database;
    await db.delete('scanned_missing');
  }

  /// All sticker codes confirmed missing via live scan.
  Future<Set<String>> getScannedMissingCodes() async {
    final db = await database;
    final rows = await db.query('scanned_missing', columns: ['code']);
    return rows.map((r) => (r['code'] as String).toUpperCase()).toSet();
  }

  /// Removes one sticker from the scanned-missing list (Missing tab).
  Future<void> removeScannedMissingCode(String code) async {
    final upper = code.toUpperCase();
    final db = await database;
    await db.delete(
      'scanned_missing',
      where: 'code = ?',
      whereArgs: [upper],
    );
  }

  /// Sets owned/need status and swap count in one transaction.
  Future<void> applyStickerState(
    String code, {
    required bool need,
    int swaps = 0,
  }) async {
    final upper = code.toUpperCase();
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      if (need) {
        await txn.insert(
          'scanned_missing',
          {'code': upper, 'last_seen_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.update(
          'collection',
          {'owned_count': 0},
          where: 'code = ?',
          whereArgs: [upper],
        );
      } else {
        await txn.delete(
          'scanned_missing',
          where: 'code = ?',
          whereArgs: [upper],
        );
        final ownedCount = (1 + swaps).clamp(1, 999);
        await txn.update(
          'collection',
          {'owned_count': ownedCount},
          where: 'code = ?',
          whereArgs: [upper],
        );
      }
    });
  }

  /// Swipe Owned: clear missing and ensure owned_count >= 1.
  Future<void> markStickerOwned(String code) async {
    final upper = code.toUpperCase();
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'scanned_missing',
        where: 'code = ?',
        whereArgs: [upper],
      );
      await txn.rawUpdate(
        'UPDATE collection SET owned_count = MAX(owned_count, 1) WHERE code = ?',
        [upper],
      );
    });
  }

  Future<void> mergeOwnedCodes(Iterable<String> codes) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final raw in codes) {
        await txn.rawUpdate(
          'UPDATE collection SET owned_count = MAX(owned_count, 1) WHERE code = ?',
          [raw.toUpperCase()],
        );
      }
    });
  }

  Future<CollectionStats> getStats() async {
    final db = await database;
    final row = await db.rawQuery('''
      SELECT
        COUNT(*) AS total,
        SUM(
          CASE
            WHEN c.owned_count >= 1 AND sm.code IS NULL THEN 1
            ELSE 0
          END
        ) AS owned,
        SUM(CASE WHEN c.owned_count >= 2 THEN c.owned_count - 1 ELSE 0 END) AS base_duplicates
      FROM collection c
      LEFT JOIN scanned_missing sm ON sm.code = c.code
    ''');
    final r = row.first;
    final scannedRows = await db.rawQuery('SELECT COUNT(*) AS n FROM scanned_missing');
    final parallelRows = await db.rawQuery('''
      SELECT COALESCE(SUM(count), 0) AS n FROM parallel_inventory
    ''');
    final baseDuplicates = (r['base_duplicates'] as int?) ?? 0;
    final parallelDuplicates = (parallelRows.first['n'] as int?) ?? 0;
    return CollectionStats(
      total: r['total']! as int,
      owned: (r['owned'] as int?) ?? 0,
      scannedMissing: (scannedRows.first['n'] as int?) ?? 0,
      duplicates: baseDuplicates + parallelDuplicates,
    );
  }

  Future<Map<String, List<Sticker>>> getGroupedByTeam({
    StickerFilter filter = StickerFilter.missing,
  }) async {
    final stickers = await getAllStickers(filter: filter);
    final byTeam = <String, List<Sticker>>{};
    for (final s in stickers) {
      byTeam.putIfAbsent(s.teamCode, () => []).add(s);
    }
    for (final list in byTeam.values) {
      list.sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
    }
    if (filter == StickerFilter.scannedMissing) {
      byTeam.removeWhere((_, stickers) => stickers.isEmpty);
    }
    return byTeam;
  }

  static const missingStickersExportType = 'missing_stickers';

  Future<String> exportMissingStickersJson() async {
    final codes = (await getScannedMissingCodes()).toList()..sort();
    return jsonEncode({
      'version': 1,
      'type': missingStickersExportType,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'codes': codes,
    });
  }

  Future<int> importMissingStickersJson(
    String jsonStr, {
    bool replace = false,
  }) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final type = data['type'] as String?;
    if (type != missingStickersExportType) {
      throw FormatException(
        'Expected type "$missingStickersExportType", got "$type"',
      );
    }
    final rawCodes = data['codes'];
    if (rawCodes is! List<dynamic>) {
      throw const FormatException('Missing or invalid "codes" array');
    }

    if (replace) {
      await clearScannedMissing();
    }

    final codes = rawCodes.map((c) => (c as String).toUpperCase()).toList();
    await mergeScannedMissingCodes(codes);
    return codes.length;
  }

  Future<void> resetCollection() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('collection', {'owned_count': 1});
      await txn.delete('scanned_missing');
      await txn.delete('parallel_inventory');
    });
  }
}

enum StickerFilter { all, owned, missing, scannedMissing, duplicates }
