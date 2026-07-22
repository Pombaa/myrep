import 'dart:async';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static const _dbName = 'fitai_trainer.db';
  static const _dbVersion = 3;

  Database? _database;
  bool _isOpening = false;

  Future<void> init() async {
    if (_database != null || _isOpening) {
      return;
    }
    _isOpening = true;
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, _dbName);
    _database = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _migrate(db, oldVersion, newVersion);
      },
    );
    _isOpening = false;
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    await init();
    return _database!;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<int> insert(String table, Map<String, Object?> values, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    final db = await database;
    return db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  Future<int> update(String table, Map<String, Object?> values, {required String where, required List<Object?> whereArgs}) async {
    final db = await database;
    return db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, Object?>>> query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) async {
    final db = await database;
    return db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        sex TEXT NOT NULL,
        height REAL NOT NULL,
        weight REAL NOT NULL,
        activity_level TEXT NOT NULL,
        objective TEXT NOT NULL,
        restrictions TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE body_measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        recorded_at TEXT NOT NULL,
        weight REAL NOT NULL,
        body_fat_percent REAL NOT NULL,
        lean_mass REAL NOT NULL,
        fat_mass REAL NOT NULL,
        bmi REAL NOT NULL,
        arm REAL,
        chest REAL,
        waist REAL,
        abdomen REAL,
        hip REAL,
        thigh REAL,
        calf REAL,
        notes TEXT,
        FOREIGN KEY(user_id) REFERENCES user_profile(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE workout_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        objective TEXT NOT NULL,
        focus TEXT,
        generated_at TEXT NOT NULL,
        metadata TEXT,
        plan_json TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES user_profile(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE workout_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER,
        executed_at TEXT NOT NULL,
        day_label TEXT NOT NULL,
        session_json TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY(plan_id) REFERENCES workout_plans(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE ai_interactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        prompt TEXT NOT NULL,
        response TEXT NOT NULL,
        metadata TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE workout_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY(user_id) REFERENCES user_profile(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE exercise_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        session_date TEXT NOT NULL,
        exercise_name TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        sets_data TEXT NOT NULL,
        progression_decision TEXT,
        rep_scheme TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES user_profile(id)
      );
    ''');
  }

  Future<void> _migrate(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE workout_reminders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          content TEXT NOT NULL,
          category TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY(user_id) REFERENCES user_profile(id)
        );
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE exercise_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          session_date TEXT NOT NULL,
          exercise_name TEXT NOT NULL,
          muscle_group TEXT NOT NULL,
          sets_data TEXT NOT NULL,
          progression_decision TEXT,
          rep_scheme TEXT NOT NULL,
          FOREIGN KEY(user_id) REFERENCES user_profile(id)
        );
      ''');
    }
  }
}
