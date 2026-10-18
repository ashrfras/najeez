import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/task.dart';
import '../domain/task_repository.dart';

class SqliteTaskRepository implements TaskRepository {
  SqliteTaskRepository._(this._database);

  final Database _database;

  static Future<SqliteTaskRepository> open({String? databasePath}) async {
    final location =
        databasePath ??
        (kIsWeb ? 'baqi.db' : path.join(await getDatabasesPath(), 'baqi.db'));
    final database = await openDatabase(
      location,
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            bucket TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            completed_at TEXT,
            pinned_at TEXT,
            scheduled_date TEXT,
            tag TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            time_entries TEXT NOT NULL DEFAULT '[]'
          )
        ''');
        await db.execute(
          'CREATE INDEX tasks_completed_at ON tasks(completed_at)',
        );
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE tasks ADD COLUMN tag TEXT');
        }
        if (oldVersion < 3) {
          await db.execute(
            "UPDATE tasks SET bucket = 'today', scheduled_date = NULL WHERE bucket = 'next'",
          );
          await db.execute(
            "UPDATE tasks SET bucket = 'later', scheduled_date = NULL WHERE bucket = 'evening'",
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE tasks ADD COLUMN time_entries TEXT NOT NULL DEFAULT '[]'",
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        }
        if (oldVersion < 6) {
          await db.execute('ALTER TABLE tasks ADD COLUMN pinned_at TEXT');
        }
      },
    );
    return SqliteTaskRepository._(database);
  }

  @override
  Future<List<Task>> getTasks() async {
    final rows = await _database.query('tasks', orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> upsertTask(Task task) async {
    await _database.insert(
      'tasks',
      _toRow(task),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<int> getLogicalDayStartMinutes() async {
    final rows = await _database.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['logical_day_start'],
    );
    return rows.isEmpty ? 0 : int.parse(rows.single['value'] as String);
  }

  @override
  Future<void> setLogicalDayStartMinutes(int minutes) async {
    await _database.insert('settings', {
      'key': 'logical_day_start',
      'value': '$minutes',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> getTimeTrackingEnabled() async {
    final rows = await _database.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['time_tracking_enabled'],
    );
    return rows.isEmpty || rows.single['value'] != 'false';
  }

  @override
  Future<void> setTimeTrackingEnabled(bool enabled) async {
    await _database.insert('settings', {
      'key': 'time_tracking_enabled',
      'value': '$enabled',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> reset() async {
    await _database.transaction((transaction) async {
      await transaction.delete('tasks');
      await transaction.delete('settings');
    });
  }

  @override
  Future<void> close() => _database.close();

  static Task _fromRow(Map<String, Object?> row) => Task(
    id: row['id'] as String,
    title: row['title'] as String,
    bucket: TaskBucket.values.byName(row['bucket'] as String),
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    completedAt: _date(row['completed_at']),
    pinnedAt: _date(row['pinned_at']),
    scheduledDate: _date(row['scheduled_date']),
    tag: row['tag'] as String?,
    isDeleted: row['is_deleted'] == 1,
    timeEntries: (jsonDecode(row['time_entries'] as String) as List<dynamic>)
        .map((value) {
          final entry = value as Map<String, dynamic>;
          return TimeEntry(
            id: entry['id'] as String,
            minutes: entry['minutes'] as int,
            createdAt: DateTime.parse(entry['created_at'] as String),
          );
        })
        .toList(),
  );

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  static Map<String, Object?> _toRow(Task task) => {
    'id': task.id,
    'title': task.title,
    'bucket': task.bucket.name,
    'created_at': task.createdAt.toIso8601String(),
    'updated_at': task.updatedAt.toIso8601String(),
    'completed_at': task.completedAt?.toIso8601String(),
    'pinned_at': task.pinnedAt?.toIso8601String(),
    'scheduled_date': task.scheduledDate?.toIso8601String(),
    'tag': task.tag,
    'is_deleted': task.isDeleted ? 1 : 0,
    'time_entries': jsonEncode(
      task.timeEntries
          .map(
            (entry) => {
              'id': entry.id,
              'minutes': entry.minutes,
              'created_at': entry.createdAt.toIso8601String(),
            },
          )
          .toList(),
    ),
  };
}
