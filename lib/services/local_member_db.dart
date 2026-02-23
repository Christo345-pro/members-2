import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/admin_models.dart';
import '../models/local_member.dart';

class LocalMemberDb {
  LocalMemberDb._();

  static final LocalMemberDb instance = LocalMemberDb._();

  Database? _db;

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;
    final opened = await _open();
    _db = opened;
    return opened;
  }

  Future<Database> _open() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await _resolveDatabasePath();

    return openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE members (
            server_id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            surname TEXT NOT NULL,
            email TEXT NOT NULL,
            account_nr TEXT,
            updated_at INTEGER NOT NULL,
            app_android INTEGER NOT NULL DEFAULT 0,
            app_windows INTEGER NOT NULL DEFAULT 0,
            app_web INTEGER NOT NULL DEFAULT 0,
            is_local_only INTEGER NOT NULL DEFAULT 0,
            is_deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_members_email ON members(email)');
        await db.execute(
          'CREATE INDEX idx_members_account_nr ON members(account_nr)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
              'ALTER TABLE members ADD COLUMN app_android INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE members ADD COLUMN app_windows INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE members ADD COLUMN app_web INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {}
        }
      },
    );
  }

  Future<String> _resolveDatabasePath() async {
    final baseDir = await getApplicationSupportDirectory();
    await baseDir.create(recursive: true);
    return p.join(baseDir.path, 'members.db');
  }

  Future<String> databasePath() => _resolveDatabasePath();

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  Future<void> upsertMember(LocalMember member) async {
    final db = await _database;
    await db.insert(
      'members',
      member.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertMembers(List<LocalMember> members) async {
    if (members.isEmpty) return;
    final db = await _database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final m in members) {
        batch.insert(
          'members',
          m.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<LocalMember>> getMembers({bool includeDeleted = false}) async {
    final db = await _database;
    final where = includeDeleted ? null : 'is_deleted = 0';
    final rows = await db.query(
      'members',
      where: where,
      orderBy: 'surname COLLATE NOCASE, name COLLATE NOCASE',
    );
    return rows.map(LocalMember.fromMap).toList();
  }

  Future<int> deleteByServerId(int serverId) async {
    final db = await _database;
    return db.delete('members', where: 'server_id = ?', whereArgs: [serverId]);
  }

  Future<void> markDeleted(int serverId) async {
    final db = await _database;
    await db.update(
      'members',
      {'is_deleted': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'server_id = ?',
      whereArgs: [serverId],
    );
  }

  Future<void> syncFromAdminUsers(List<AdminUser> users) async {
    final now = DateTime.now();
    final members = <LocalMember>[];
    final serverIds = <int>[];

    for (final u in users) {
      final email = u.email.trim();
      if (email.isEmpty) continue;
      members.add(
        LocalMember(
          serverId: u.id,
          name: (u.name ?? '').trim(),
          surname: (u.surname ?? '').trim(),
          email: email,
          accountNr: (u.accountNumber ?? '').trim(),
          updatedAt: now,
          appAndroid: u.appAndroid == true,
          appWindows: u.appWindows == true,
          appWeb: u.appWeb == true,
          isLocalOnly: false,
          isDeleted: false,
        ),
      );
      serverIds.add(u.id);
    }

    final db = await _database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final m in members) {
        batch.insert(
          'members',
          m.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);

      if (serverIds.isEmpty) {
        await txn.delete('members', where: 'is_local_only = 0');
        return;
      }

      final placeholders = List.filled(serverIds.length, '?').join(',');
      await txn.delete(
        'members',
        where: 'is_local_only = 0 AND server_id NOT IN ($placeholders)',
        whereArgs: serverIds,
      );
    });
  }

  Future<String> exportJsonSnapshot() async {
    final rows = await getMembers(includeDeleted: false);
    final dbPath = await _resolveDatabasePath();
    final exportDir = Directory(p.join(p.dirname(dbPath), 'exports'));
    await exportDir.create(recursive: true);

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final path = p.join(exportDir.path, 'members_export_$timestamp.json');
    final payload = <String, dynamic>{
      'generated_at': DateTime.now().toIso8601String(),
      'database_path': dbPath,
      'count': rows.length,
      'members': rows.map((e) => e.toJson()).toList(),
    };

    await File(path).writeAsString(jsonEncode(payload), flush: true);
    return path;
  }
}
