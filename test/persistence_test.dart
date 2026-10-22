import 'dart:io';
import 'package:baqi/features/tasks/data/sqlite_task_repository.dart';
import 'package:baqi/features/tasks/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test('SQLite persists timestamps and soft deletion across opens', () async {
    final directory = await Directory.systemTemp.createTemp('baqi_test_');
    final dbPath = '${directory.path}/tasks.db';
    final created = DateTime(2026, 10, 11, 10, 24);
    final repository = await SqliteTaskRepository.open(databasePath: dbPath);
    expect(await repository.getLogicalDayStartMinutes(), 0);
    expect(await repository.getTimeTrackingEnabled(), isTrue);
    await repository.setCategoryColor('عمل', 0xFFFF474D);
    await repository.setTimeTrackingEnabled(false);
    await repository.setLogicalDayStartMinutes(240);
    await repository.upsertTask(
      Task(
        id: 'stable-id',
        title: 'مهمة',
        bucket: TaskBucket.today,
        createdAt: created,
        updatedAt: created,
        completedAt: created,
        tag: 'عمل',
        isDeleted: true,
        timeEntries: [
          TimeEntry(id: 'entry-1', minutes: 95, createdAt: created),
        ],
      ),
    );
    await repository.close();
    final reopened = await SqliteTaskRepository.open(databasePath: dbPath);
    expect(await reopened.getCategoryColors(), {'عمل': 0xFFFF474D});
    final task = (await reopened.getTasks()).single;
    expect(await reopened.getLogicalDayStartMinutes(), 240);
    expect(await reopened.getTimeTrackingEnabled(), isFalse);
    await reopened.setTimeTrackingEnabled(true);
    expect((await reopened.getTasks()).single.totalMinutes, 95);
    expect(task.id, 'stable-id');
    expect(task.completedAt, created);
    expect(task.isDeleted, isTrue);
    expect(task.tag, 'عمل');
    expect(task.totalMinutes, 95);
    expect(task.timeEntries.single.id, 'entry-1');
    await reopened.close();
    final enabled = await SqliteTaskRepository.open(databasePath: dbPath);
    expect(await enabled.getTimeTrackingEnabled(), isTrue);
    expect((await enabled.getTasks()).single.totalMinutes, 95);
    await enabled.setTimeTrackingEnabled(false);
    await enabled.reset();
    expect(await enabled.getCategoryColors(), isEmpty);
    expect(await enabled.getTimeTrackingEnabled(), isTrue);
    await enabled.close();
    await directory.delete(recursive: true);
  });

  test('existing version 1 database migrates without losing tasks', () async {
    final directory = await Directory.systemTemp.createTemp('baqi_migrate_');
    final dbPath = '${directory.path}/tasks.db';
    final old = await sqflite.openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE tasks (
        id TEXT PRIMARY KEY, title TEXT NOT NULL, bucket TEXT NOT NULL,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        completed_at TEXT, scheduled_date TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0)''');
        await db.insert('tasks', {
          'id': 'old-id',
          'title': 'مهمة قديمة',
          'bucket': 'next',
          'created_at': '2026-10-11T10:24:00.000',
          'updated_at': '2026-10-11T10:24:00.000',
          'is_deleted': 0,
        });
      },
    );
    await old.close();
    final repository = await SqliteTaskRepository.open(databasePath: dbPath);
    final task = (await repository.getTasks()).single;
    expect(task.title, 'مهمة قديمة');
    expect(task.bucket, TaskBucket.today);
    expect(task.tag, isNull);
    expect(task.timeEntries, isEmpty);
    expect(await repository.getLogicalDayStartMinutes(), 0);
    await repository.upsertTask(task.copyWith(tag: 'جديد'));
    expect((await repository.getTasks()).single.tag, 'جديد');
    await repository.close();
    await directory.delete(recursive: true);
  });

  test('version 2 buckets migrate to today and later', () async {
    final directory = await Directory.systemTemp.createTemp('baqi_buckets_');
    final dbPath = '${directory.path}/tasks.db';
    final old = await sqflite.openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE tasks (
        id TEXT PRIMARY KEY, title TEXT NOT NULL, bucket TEXT NOT NULL,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        completed_at TEXT, scheduled_date TEXT, tag TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0)''');
        for (final bucket in ['next', 'evening', 'tomorrow']) {
          await db.insert('tasks', {
            'id': bucket,
            'title': bucket,
            'bucket': bucket,
            'created_at': '2026-10-11T10:24:00.000',
            'updated_at': '2026-10-11T10:24:00.000',
            'scheduled_date': bucket == 'next'
                ? null
                : '2026-10-12T00:00:00.000',
          });
        }
      },
    );
    await old.close();

    final repository = await SqliteTaskRepository.open(databasePath: dbPath);
    final tasks = {
      for (final task in await repository.getTasks()) task.id: task,
    };
    expect(tasks['next']!.bucket, TaskBucket.today);
    expect(tasks['next']!.scheduledDate, isNull);
    expect(tasks['evening']!.bucket, TaskBucket.later);
    expect(tasks['evening']!.scheduledDate, isNull);
    expect(tasks['tomorrow']!.bucket, TaskBucket.tomorrow);
    expect(tasks['tomorrow']!.scheduledDate, DateTime(2026, 10, 12));
    await repository.close();
    await directory.delete(recursive: true);
  });
}
