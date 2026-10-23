import 'dart:io';
import 'dart:convert';

import 'package:baqi/main.dart';
import 'package:baqi/core/design.dart';
import 'package:baqi/features/tasks/data/sqlite_task_repository.dart';
import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:baqi/features/tasks/presentation/task_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'task_behavior_test.dart' show MemoryRepository;

class RepeatRepository extends MemoryRepository {
  final repeats = <String, DailyRepeat>{};
  bool failGeneration = false;
  @override
  Future<List<DailyRepeat>> getDailyRepeats() async => repeats.values.toList();
  @override
  Future<void> saveDailyRepeat(DailyRepeat repeat, {Task? task}) async {
    repeats[repeat.id] = repeat;
    if (task != null) await super.upsertTask(task);
  }

  @override
  Future<void> upsertTask(Task task) async {
    if (failGeneration && task.id.startsWith('daily:')) {
      throw StateError('disk unavailable');
    }
    await super.upsertTask(task);
  }

  @override
  Future<void> reset() async {
    await super.reset();
    repeats.clear();
  }
}

void main() {
  late RepeatRepository repository;
  late TaskController controller;
  late DateTime now;
  setUp(() async {
    now = DateTime(2026, 10, 15, 9);
    repository = RepeatRepository();
    controller = TaskController(repository, clock: () => now);
    await controller.load();
    await controller.create('قراءة', tag: 'شخصي');
  });
  tearDown(() => controller.dispose());

  test(
    'daily copies have independent completion, time, and pin state',
    () async {
      final original = controller.tasks.single;
      await controller.setDailyRepeat(original, true);
      await controller.setPinned(original, true);
      await controller.addTimeEntry(original, hours: 1, minutes: 5);
      await controller.complete(original);
      now = DateTime(2026, 10, 16, 9);
      await controller.refreshDay();
      final today = TaskListKind.today.select(controller).single;
      expect(today.id, isNot(original.id));
      expect(today.repeatDay, DateTime(2026, 10, 16));
      expect(today.timeEntries, isEmpty);
      expect(today.isCompleted, isFalse);
      expect(today.isPinned, isFalse);
      expect(today.tag, 'شخصي');
      final yesterday = controller.tasks.firstWhere((t) => t.id == original.id);
      expect(yesterday.completedAt, DateTime(2026, 10, 15, 9));
      expect(yesterday.totalMinutes, 65);
      await controller.addTimeEntry(today, hours: 0, minutes: 10);
      await controller.complete(today);
      expect(
        controller.tasks.firstWhere((t) => t.id == original.id).totalMinutes,
        65,
      );
      expect(
        controller.tasks.firstWhere((t) => t.id == today.id).totalMinutes,
        10,
      );
    },
  );

  test(
    'respects boundary and concurrent refresh; skips missed days on load',
    () async {
      await controller.setLogicalDayStart(240);
      await controller.setDailyRepeat(controller.tasks.single, true);
      now = DateTime(2026, 10, 16, 3, 59);
      await controller.refreshDay();
      expect(controller.tasks, hasLength(1));
      now = DateTime(2026, 10, 16, 4);
      await Future.wait(List.generate(8, (_) => controller.refreshDay()));
      expect(controller.tasks, hasLength(2));
      now = DateTime(2026, 10, 20, 4);
      final reopened = TaskController(repository, clock: () => now);
      addTearDown(reopened.dispose);
      await reopened.load();
      expect(reopened.tasks, hasLength(3));
      expect(
        reopened.tasks.map((t) => t.repeatDay),
        contains(DateTime(2026, 10, 20)),
      );
      await reopened.load();
      expect(reopened.tasks, hasLength(3));
    },
  );

  test(
    'deleting or moving today never recreates it; next day still repeats',
    () async {
      final original = controller.tasks.single;
      await controller.setDailyRepeat(original, true);
      await controller.move(original, TaskBucket.later);
      await controller.refreshDay();
      expect(controller.tasks, hasLength(1));
      await controller.delete(original);
      await controller.load();
      expect(controller.tasks, isEmpty);
      now = DateTime(2026, 10, 16, 9);
      await controller.refreshDay();
      expect(controller.tasks.single.bucket, TaskBucket.today);
      expect(repository.records, hasLength(2));
    },
  );

  test(
    'stopping preserves history and titles change only for future copies',
    () async {
      final original = controller.tasks.single;
      await controller.setDailyRepeat(original, true);
      await controller.complete(original);
      await controller.update(
        original,
        'قراءة جديدة',
        bucket: TaskBucket.today,
        tag: 'شخصي',
      );
      expect(controller.tasks.single.title, 'قراءة');
      now = DateTime(2026, 10, 16, 9);
      await controller.refreshDay();
      final today = controller.tasks.first;
      expect(today.title, 'قراءة جديدة');
      await controller.setDailyRepeat(today, false);
      now = DateTime(2026, 10, 17, 9);
      await controller.load();
      expect(controller.tasks, hasLength(2));
      expect(
        controller.tasks.firstWhere((t) => t.id == original.id).isCompleted,
        isTrue,
      );
      await controller.setDailyRepeat(today, true);
      expect(controller.tasks, hasLength(3));
      await controller.delete(controller.tasks.first, stopRepeating: true);
      now = DateTime(2026, 10, 18, 9);
      await controller.refreshDay();
      expect(controller.tasks, hasLength(2));
      expect(repository.repeats.values.single.enabled, isFalse);
    },
  );

  test(
    'enabling completed history preserves it and creates only today',
    () async {
      final original = controller.tasks.single;
      await controller.complete(original);
      now = DateTime(2026, 10, 20, 9);
      await controller.setDailyRepeat(original, true);
      expect(controller.tasks, hasLength(2));
      expect(controller.tasks.first.repeatDay, DateTime(2026, 10, 20));
      expect(controller.tasks.last.repeatDay, DateTime(2026, 10, 15));
      expect(controller.tasks.last.isCompleted, isTrue);
    },
  );

  test(
    'changing logical start uses stored occurrence day without duplication',
    () async {
      now = DateTime(2026, 10, 16, 2);
      await controller.setLogicalDayStart(240);
      await controller.setDailyRepeat(controller.tasks.single, true);
      expect(controller.tasks.single.repeatDay, DateTime(2026, 10, 15));
      await controller.setLogicalDayStart(0);
      expect(controller.tasks, hasLength(2));
      await controller.setLogicalDayStart(240);
      await controller.setLogicalDayStart(0);
      expect(controller.tasks, hasLength(2));
    },
  );

  test(
    'failed generation retries safely and queue survives failures',
    () async {
      await controller.setDailyRepeat(controller.tasks.single, true);
      now = DateTime(2026, 10, 16, 9);
      repository.failGeneration = true;
      await controller.refreshDay();
      expect(controller.error, isNotNull);
      expect(controller.tasks, hasLength(1));
      repository.failGeneration = false;
      await controller.refreshDay();
      expect(controller.error, isNull);
      expect(controller.tasks, hasLength(2));
      await controller.reset();
      await controller.refreshDay();
      expect(controller.tasks, isEmpty);
      expect(repository.repeats, isEmpty);
    },
  );

  test(
    'SQLite reopen and backup preserve templates, deletion and independence',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp('daily_repeat_');
      final path = '${directory.path}/tasks.db';
      var sqlite = await SqliteTaskRepository.open(databasePath: path);
      var local = TaskController(sqlite, clock: () => now);
      await local.load();
      await local.create('عادة');
      final task = local.tasks.single;
      await local.setDailyRepeat(task, true);
      await local.delete(task);
      final backup = await sqlite.exportBackup();
      local.dispose();
      await sqlite.close();
      sqlite = await SqliteTaskRepository.open(databasePath: path);
      local = TaskController(sqlite, clock: () => now);
      await local.load();
      expect(local.tasks, isEmpty);
      await sqlite.reset();
      await sqlite.importBackup(backup, now);
      await local.load();
      expect(local.tasks, isEmpty);
      now = DateTime(2026, 10, 20, 9);
      await local.refreshDay();
      expect(local.tasks.single.title, 'عادة');
      expect((await sqlite.getTasks()), hasLength(2));
      local.dispose();
      await sqlite.close();
      await directory.delete(recursive: true);
    },
  );

  test('old backups without repeat fields restore as ordinary tasks', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final sqlite = await SqliteTaskRepository.open(
      databasePath: inMemoryDatabasePath,
    );
    await sqlite.upsertTask(controller.tasks.single);
    final payload =
        jsonDecode(utf8.decode(await sqlite.exportBackup()))
            as Map<String, dynamic>;
    for (final row in payload['tasks'] as List) {
      (row as Map).remove('repeat_id');
      row.remove('repeat_day');
    }
    await sqlite.importBackup(utf8.encode(jsonEncode(payload)), now);
    final ordinary = (await sqlite.getTasks()).single;
    expect(ordinary.title, 'قراءة');
    expect(ordinary.repeatId, isNull);
    expect(await sqlite.getDailyRepeats(), isEmpty);
    await sqlite.close();
  });

  testWidgets(
    'open app rolls over at logical boundary and resumes after absence',
    (tester) async {
      final repository = RepeatRepository();
      var instant = DateTime(2026, 10, 16, 3, 59, 59);
      final controller = TaskController(repository, clock: () => instant);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.setLogicalDayStart(240);
      await controller.create('روتين');
      await controller.setDailyRepeat(controller.tasks.single, true);
      await controller.complete(controller.tasks.single);
      await tester.pumpWidget(
        BaqiApp(controller: controller, splashDuration: Duration.zero),
      );
      await tester.pumpAndSettle();
      instant = DateTime(2026, 10, 16, 4);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(controller.tasks, hasLength(2));
      expect(
        TaskListKind.today.select(controller).single.repeatDay,
        DateTime(2026, 10, 16),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      instant = DateTime(2026, 10, 21, 9);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(controller.tasks, hasLength(3));
      expect(controller.tasks.first.repeatDay, DateTime(2026, 10, 21));
      await controller.refreshDay();
      expect(controller.tasks, hasLength(3));
    },
  );

  testWidgets(
    'menu stop requires confirmation and cancellation preserves repeat',
    (tester) async {
      final controller = TaskController(RepeatRepository());
      addTearDown(controller.dispose);
      await controller.load();
      await controller.create('قراءة');
      await controller.setDailyRepeat(controller.tasks.single, true);
      await tester.pumpWidget(
        BaqiApp(controller: controller, splashDuration: Duration.zero),
      );
      await tester.pumpAndSettle();
      Future<void> openStop() async {
        await tester.tap(find.text('قراءة'));
        await tester.pumpAndSettle();
        expect(find.text('إيقاف التكرار اليومي'), findsOneWidget);
        expect(find.text('حذف المهمة'), findsNothing);
        await tester.ensureVisible(find.text('المزيد'));
        await tester.tap(find.text('المزيد'));
        await tester.pumpAndSettle();
        expect(find.text('إيقاف التكرار اليومي'), findsOneWidget);
        expect(find.text('حذف المهمة'), findsOneWidget);
        await tester.ensureVisible(find.text('إخفاء'));
        await tester.tap(find.text('إخفاء'));
        await tester.pumpAndSettle();
        expect(find.text('حذف المهمة'), findsNothing);
        expect(find.text('إيقاف التكرار اليومي'), findsOneWidget);
        await tester.ensureVisible(find.text('إيقاف التكرار اليومي'));
        await tester.tap(find.text('إيقاف التكرار اليومي'));
        await tester.pumpAndSettle();
        expect(find.text('إيقاف التكرار اليومي؟'), findsOneWidget);
        expect(
          find.text(
            'لن تُضاف هذه المهمة تلقائيًا إلى قائمة «اليوم» بعد الآن، وستبقى المهام السابقة وسجلات إنجازها محفوظة.',
          ),
          findsOneWidget,
        );
        expect(controller.repeatsDaily(controller.tasks.single), isTrue);
      }

      await openStop();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(controller.repeatsDaily(controller.tasks.single), isTrue);
      await openStop();
      await tester.tap(find.text('إيقاف التكرار'));
      await tester.pumpAndSettle();
      expect(controller.repeatsDaily(controller.tasks.single), isFalse);
      expect(controller.tasks.single.title, 'قراءة');
    },
  );

  testWidgets(
    'more reveals repeat and deletion; editing preserves repeat without controls',
    (tester) async {
      final repository = RepeatRepository();
      final controller = TaskController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.create('قراءة', tag: 'شخصي');
      await tester.pumpWidget(
        BaqiApp(controller: controller, splashDuration: Duration.zero),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('قراءة'));
      await tester.pumpAndSettle();
      expect(find.text('تمت المهمة'), findsNothing);
      expect(find.text('نقل إلى غداً'), findsOneWidget);
      expect(find.text('نقل إلى لاحقاً'), findsOneWidget);
      expect(find.text('تكرار يومي'), findsNothing);
      await tester.ensureVisible(find.text('المزيد'));
      await tester.tap(find.text('المزيد'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'إخفاء'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text('تكرار يومي'), findsOneWidget);
      expect(find.text('حذف المهمة'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('إخفاء')).dy,
        greaterThan(tester.getBottomLeft(find.text('حذف المهمة')).dy),
      );
      await tester.ensureVisible(find.text('إخفاء'));
      await tester.tap(find.text('إخفاء'));
      await tester.pumpAndSettle();
      expect(find.text('تكرار يومي'), findsNothing);
      expect(find.text('حذف المهمة'), findsNothing);
      expect(find.text('تعديل المهمة'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'المزيد'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(controller.repeatsDaily(controller.tasks.single), isFalse);
      await tester.tap(find.text('المزيد'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('تكرار يومي'));
      await tester.tap(find.text('تكرار يومي'));
      await tester.pumpAndSettle();
      expect(find.text('تفعيل التكرار اليومي؟'), findsOneWidget);
      expect(controller.repeatsDaily(controller.tasks.single), isFalse);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(controller.repeatsDaily(controller.tasks.single), isFalse);
      await tester.tap(find.text('قراءة'));
      await tester.pumpAndSettle();
      expect(find.text('تكرار يومي'), findsNothing);
      await tester.ensureVisible(find.text('المزيد'));
      await tester.tap(find.text('المزيد'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('تكرار يومي'));
      await tester.tap(find.text('تكرار يومي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تفعيل التكرار'));
      await tester.pumpAndSettle();
      expect(controller.repeatsDaily(controller.tasks.single), isTrue);
      expect(find.byIcon(Icons.repeat), findsOneWidget);
      await tester.tap(find.text('قراءة'));
      await tester.pumpAndSettle();
      expect(find.text('حذف المهمة'), findsNothing);
      expect(find.text('تمت المهمة'), findsNothing);
      expect(find.textContaining('نقل إلى'), findsNothing);
      await tester.ensureVisible(find.text('المزيد'));
      await tester.tap(find.text('المزيد'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('حذف المهمة'));
      await tester.tap(find.text('حذف المهمة'));
      await tester.pumpAndSettle();
      expect(find.text('حذف هذه النسخة فقط'), findsOneWidget);
      expect(find.text('حذف وإيقاف التكرار'), findsOneWidget);
      final deleteButton = find.widgetWithText(
        FilledButton,
        'حذف هذه النسخة فقط',
      );
      final button = tester.widget<FilledButton>(deleteButton);
      expect(button.style?.backgroundColor, isNull);
      expect(
        button
            .defaultStyleOf(tester.element(deleteButton))
            .backgroundColor!
            .resolve({}),
        AppColors.blue,
      );
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('قراءة'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('تعديل المهمة'));
      await tester.tap(find.text('تعديل المهمة'));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text('تكرار يومي'), findsNothing);
      expect(find.text('إيقاف التكرار اليومي'), findsNothing);
      for (final label in ['غداً', 'لاحقاً']) {
        final option = find
            .ancestor(of: find.text(label), matching: find.byType(InkWell))
            .first;
        expect(tester.widget<InkWell>(option).onTap, isNull);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(controller.repeatsDaily(controller.tasks.single), isTrue);
      expect(find.byIcon(Icons.repeat), findsOneWidget);
      expect(controller.tasks.single.title, 'قراءة');
      expect(controller.tasks.single.bucket, TaskBucket.today);
    },
  );
}
