import 'dart:io';

import 'package:baqi/main.dart';
import 'package:baqi/features/tasks/data/sqlite_task_repository.dart';
import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:baqi/features/tasks/domain/task_repository.dart';
import 'package:baqi/features/tasks/presentation/task_list_screen.dart';
import 'package:baqi/features/tasks/presentation/task_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class PinRepository extends TaskRepository {
  final records = <String, Task>{};
  bool failSave = false;

  @override
  Future<List<Task>> getTasks() async => records.values.toList();

  @override
  Future<void> upsertTask(Task task) async {
    if (failSave) throw StateError('Save failed');
    records[task.id] = task;
  }

  @override
  Future<void> reset() async => records.clear();

  @override
  Future<void> close() async {}
}

void main() {
  final now = DateTime(2026, 10, 18, 12);

  TaskController controllerFor(PinRepository repository) {
    final controller = TaskController(repository, clock: () => now);
    addTearDown(controller.dispose);
    return controller;
  }

  test('newest pin stays first through edits, new tasks and reloads', () async {
    final repository = PinRepository();
    final controller = controllerFor(repository);
    await controller.load();
    await controller.create('أولى');
    final first = controller.tasks.single;
    await controller.create('ثانية');
    final second = controller.tasks.first;
    await controller.setPinned(first, true);
    await controller.setPinned(second, true);
    await controller.update(first, 'أولى معدلة', bucket: TaskBucket.today);
    await controller.addTimeEntry(first, hours: 0, minutes: 10);
    await controller.create('جديدة');
    expect(TaskListKind.today.select(controller).map((task) => task.title), [
      'ثانية',
      'أولى معدلة',
      'جديدة',
    ]);
    await controller.load();
    expect(
      TaskListKind.today.select(controller).take(2).map((task) => task.id),
      [second.id, first.id],
    );
    await controller.setPinned(first, false);
    await controller.setPinned(first, true);
    expect(TaskListKind.today.select(controller).first.id, first.id);
  });

  for (final bucket in [TaskBucket.tomorrow, TaskBucket.later]) {
    for (final edit in [false, true]) {
      test('moving to $bucket (edit: $edit) permanently clears pin', () async {
        final controller = controllerFor(PinRepository());
        await controller.load();
        await controller.create('مهمة');
        final original = controller.tasks.single;
        await controller.setPinned(original, true);
        if (edit) {
          await controller.update(original, 'مهمة معدلة', bucket: bucket);
        } else {
          await controller.move(original, bucket);
        }
        expect(controller.tasks.single.isPinned, isFalse);
        await controller.move(original, TaskBucket.today);
        expect(controller.tasks.single.isPinned, isFalse);
        await controller.load();
        expect(controller.tasks.single.isPinned, isFalse);
      });
    }
  }

  test('completion and restoration never bring the pin back', () async {
    final controller = controllerFor(PinRepository());
    await controller.load();
    await controller.create('مهمة');
    final original = controller.tasks.single;
    await controller.setPinned(original, true);
    await controller.complete(original);
    expect(controller.tasks.single.isPinned, isFalse);
    await controller.restore(original);
    expect(controller.tasks.single.isPinned, isFalse);
    await controller.setPinned(original, true);
    await controller.delete(original);
    expect(controller.tasks, isEmpty);
  });

  test(
    'only active today tasks can be pinned, including rolled over tasks',
    () async {
      final repository = PinRepository();
      var clock = now;
      final controller = TaskController(repository, clock: () => clock);
      addTearDown(controller.dispose);
      await controller.load();
      for (final bucket in [TaskBucket.tomorrow, TaskBucket.later]) {
        await controller.create(bucket.name, bucket: bucket);
        await controller.setPinned(controller.tasks.first, true);
        expect(controller.tasks.first.isPinned, isFalse);
      }
      final tomorrow = controller.tasks.firstWhere(
        (task) => task.bucket == TaskBucket.tomorrow,
      );
      clock = now.add(const Duration(days: 1));
      await controller.setPinned(tomorrow, true);
      expect(controller.tasks.first.isPinned, isTrue);
      await controller.complete(tomorrow);
      await controller.setPinned(tomorrow, true);
      expect(controller.tasks.first.isPinned, isFalse);
      await controller.delete(tomorrow);
      await controller.setPinned(tomorrow, true);
      expect(repository.records[tomorrow.id]!.isPinned, isFalse);
    },
  );

  test('failed pin and failed move restore the previous state', () async {
    final repository = PinRepository();
    final controller = controllerFor(repository);
    await controller.load();
    await controller.create('مهمة');
    final task = controller.tasks.single;
    repository.failSave = true;
    await expectLater(controller.setPinned(task, true), throwsStateError);
    expect(controller.tasks.single.isPinned, isFalse);
    repository.failSave = false;
    await controller.setPinned(task, true);
    repository.failSave = true;
    await expectLater(
      controller.move(task, TaskBucket.later),
      throwsStateError,
    );
    expect(controller.tasks.single.isPinned, isTrue);
    expect(controller.tasks.single.bucket, TaskBucket.today);
  });

  test(
    'version 5 migration preserves tasks and stores pin order across opens',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp('najeez_pins_');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/tasks.db';
      final old = await sqflite.openDatabase(
        path,
        version: 5,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE tasks (
        id TEXT PRIMARY KEY, title TEXT NOT NULL, bucket TEXT NOT NULL,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        completed_at TEXT, scheduled_date TEXT, tag TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        time_entries TEXT NOT NULL DEFAULT '[]')''');
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.insert('tasks', {
            'id': 'old',
            'title': 'قديمة',
            'bucket': 'today',
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          });
        },
      );
      await old.close();
      final repository = await SqliteTaskRepository.open(databasePath: path);
      final controller = TaskController(repository, clock: () => now);
      await controller.load();
      expect(controller.tasks.single.isPinned, isFalse);
      await controller.setPinned(controller.tasks.single, true);
      await controller.create('جديدة');
      await controller.setPinned(controller.tasks.first, true);
      await repository.close();
      controller.dispose();
      final reopened = await SqliteTaskRepository.open(databasePath: path);
      final restored = TaskController(reopened, clock: () => now);
      await restored.load();
      expect(TaskListKind.today.select(restored).map((task) => task.title), [
        'جديدة',
        'قديمة',
      ]);
      expect(restored.tasks.every((task) => task.isPinned), isTrue);
      await restored.move(restored.tasks.first, TaskBucket.later);
      await reopened.close();
      restored.dispose();
      final finalRepository = await SqliteTaskRepository.open(
        databasePath: path,
      );
      final tasks = await finalRepository.getTasks();
      expect(
        tasks.singleWhere((task) => task.bucket == TaskBucket.later).isPinned,
        isFalse,
      );
      await finalRepository.close();
    },
  );

  testWidgets(
    'pin action orders home and full list, with icon and unpin action',
    (tester) async {
      final controller = controllerFor(PinRepository());
      await controller.load();
      await controller.create('أولى');
      await controller.create('ثانية');
      await tester.pumpWidget(
        BaqiApp(controller: controller, splashDuration: Duration.zero),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('أولى'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تثبيت المهمة'));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<TaskRow>(find.byType(TaskRow)).first.task.title,
        'أولى',
      );
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      await tester.tap(find.text('ثانية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تثبيت المهمة'));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<TaskRow>(find.byType(TaskRow)).first.task.title,
        'ثانية',
      );
      await tester.tap(find.text('اليوم').last);
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);
      expect(
        tester.widgetList<TaskRow>(find.byType(TaskRow)).first.task.title,
        'ثانية',
      );
      await tester.tap(find.text('ثانية'));
      await tester.pumpAndSettle();
      expect(find.text('إلغاء التثبيت'), findsOneWidget);
      await tester.tap(find.text('إلغاء التثبيت'));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<TaskRow>(find.byType(TaskRow)).first.task.title,
        'أولى',
      );
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
