import 'dart:async';
import 'dart:io';

import 'package:baqi/features/tasks/data/sqlite_task_repository.dart';
import 'package:baqi/features/tasks/domain/task.dart';
import 'package:baqi/features/tasks/domain/task_controller.dart';
import 'package:baqi/features/tasks/domain/task_repository.dart';
import 'package:baqi/features/settings/presentation/settings_screen.dart';
import 'package:baqi/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ResetRepository extends TaskRepository {
  final tasks = <Task>[];
  int minutes = 240;
  int resetCalls = 0;
  Completer<void>? gate;

  @override
  Future<List<Task>> getTasks() async => List.of(tasks);
  @override
  Future<int> getLogicalDayStartMinutes() async => minutes;
  @override
  Future<void> upsertTask(Task task) async => tasks.add(task);
  @override
  Future<void> reset() async {
    resetCalls++;
    await gate?.future;
    tasks.clear();
    minutes = 0;
  }

  @override
  Future<void> close() async {}
}

void main() {
  test('reset clears persisted data and defaults across reopen', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp('najeez_reset_');
    addTearDown(() => directory.delete(recursive: true));
    final dbPath = '${directory.path}/tasks.db';
    final repository = await SqliteTaskRepository.open(databasePath: dbPath);
    final controller = TaskController(repository);
    await controller.load();
    await controller.setLogicalDayStart(240);
    await controller.create('مهمة مكتملة', tag: 'عمل');
    await controller.addTimeEntry(
      controller.tasks.single,
      hours: 1,
      minutes: 15,
    );
    await controller.complete(controller.tasks.single);
    await controller.create('مهمة محذوفة', tag: 'شخصي');
    await controller.delete(controller.tasks.first);
    await controller.reset();
    expect(controller.tasks, isEmpty);
    expect(controller.availableTags, isEmpty);
    expect(controller.logicalDay.startMinutes, 0);
    expect(await repository.getTasks(), isEmpty);
    await repository.close();

    final reopened = await SqliteTaskRepository.open(databasePath: dbPath);
    expect(await reopened.getTasks(), isEmpty);
    expect(await reopened.getLogicalDayStartMinutes(), 0);
    final fresh = TaskController(reopened);
    await fresh.load();
    await fresh.create('مهمة جديدة');
    expect((await reopened.getTasks()).single.title, 'مهمة جديدة');
    await reopened.close();
    controller.dispose();
    fresh.dispose();
  });

  testWidgets('reset requires confirmation and returns to empty home', (
    tester,
  ) async {
    final repository = ResetRepository();
    final controller = TaskController(repository);
    await controller.load();
    await controller.create('مهمة موجودة', tag: 'عمل');
    await tester.pumpWidget(
      BaqiApp(controller: controller, splashDuration: Duration.zero),
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('إعادة الضبط'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إعادة الضبط'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ولا يمكن استرجاع البيانات'), findsOneWidget);
    expect(repository.resetCalls, 0);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(controller.tasks, hasLength(1));
    expect(controller.logicalDay.startMinutes, 240);
    await tester.tap(find.text('إعادة الضبط'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف جميع البيانات'));
    await tester.pumpAndSettle();
    expect(repository.resetCalls, 1);
    expect(controller.tasks, isEmpty);
    expect(controller.availableTags, isEmpty);
    expect(controller.logicalDay.startMinutes, 0);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('مهمة موجودة'), findsNothing);
    expect(
      find.text('تم حذف جميع البيانات وإعادة ضبط التطبيق.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'reset blocks duplicate taps and preserves data on failure with retry',
    (tester) async {
      final repository = ResetRepository()..gate = Completer<void>();
      final controller = TaskController(repository);
      await controller.load();
      await controller.create('مهمة محفوظة', tag: 'عمل');
      await tester.pumpWidget(
        BaqiApp(controller: controller, splashDuration: Duration.zero),
      );
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('إعادة الضبط'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إعادة الضبط'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف جميع البيانات'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'إلغاء'))
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(repository.resetCalls, 1);
      repository.gate!.completeError(StateError('Storage unavailable'));
      await tester.pumpAndSettle();
      expect(find.textContaining('تعذّرت إعادة الضبط'), findsOneWidget);
      expect(controller.tasks.single.title, 'مهمة محفوظة');
      expect(controller.logicalDay.startMinutes, 240);
      expect(controller.availableTags, ['عمل']);
      repository.gate = null;
      await tester.tap(find.text('حذف جميع البيانات'));
      await tester.pumpAndSettle();
      expect(repository.resetCalls, 2);
      expect(controller.tasks, isEmpty);
      expect(find.byType(SettingsScreen), findsNothing);
    },
  );
}
